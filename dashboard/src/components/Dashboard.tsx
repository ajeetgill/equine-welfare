import { useCallback, useEffect, useState } from "react";
import { Download, Loader2, Trash2 } from "lucide-react";
import { Packer } from "docx";
import { saveAs } from "file-saver";
import JSZip from "jszip";
import generateDocument from "../actions/docxReport";
import { generateHorseDoc } from "../actions/docGeneration";
import { BackendErrorMessage } from "./BackendError";
import { getPocketBase } from "../lib/pocketbase";
import {
  AssessmentRecord,
  deleteAssessmentCascade,
  fetchAssessmentDetails,
  fetchAssessmentMedia,
} from "../lib/assessments";

// Strip characters that are illegal in file/zip paths so a horse or farm name
// can't break the folder structure or overwrite a sibling entry.
function sanitizeName(name: string): string {
  return name.replace(/[/\\:*?"<>|\x00-\x1f]/g, "_").trim();
}

export default function Dashboard({ email }: { email: string | null }) {
  const [assessments, setAssessments] = useState<AssessmentRecord[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);

  const reload = useCallback(async () => {
    try {
      const records = await getPocketBase()
        .collection("assessments")
        .getFullList<AssessmentRecord>({ sort: "-created" });
      setAssessments(records);
      setLoadError(null);
    } catch (err) {
      const status = (err as { status?: number }).status;
      if (status === 401 || status === 403) {
        // Token expired or user removed — clear auth; App's onChange
        // listener switches to the Login screen.
        getPocketBase().authStore.clear();
        return;
      }
      setLoadError("Could not connect to the PocketBase backend.");
    }
  }, []);

  useEffect(() => {
    const pb = getPocketBase();
    reload();
    // Realtime: re-fetch the list on any assessments change (replaces the
    // Convex useQuery live subscription).
    pb.collection("assessments").subscribe("*", () => reload());
    return () => {
      pb.collection("assessments").unsubscribe("*");
    };
  }, [reload]);

  if (loadError) {
    return <BackendErrorMessage message={loadError} />;
  }

  if (!assessments) {
    return (
      <div className="flex flex-col gap-6 w-11/12 max-w-3xl">
        <h2>Loading...</h2>
      </div>
    );
  }

  const handleDelete = async (assessment: AssessmentRecord) => {
    if (confirm("Are you sure you want to delete this assessment?")) {
      try {
        await deleteAssessmentCascade(assessment);
        await reload();
      } catch (error) {
        alert(
          `Delete failed: ${error instanceof Error ? error.message : "Unknown error"}`
        );
      }
    }
  };

  const handleDownload = async (assessment: AssessmentRecord) => {
    setDownloadingId(assessment.id);
    try {
      const details = await fetchAssessmentDetails(assessment.id);
      const media = await fetchAssessmentMedia(details, details.horses);

      const zip = new JSZip();

      // 1. Generate assessment report .docx
      const horses = details.horses.filter((h) => h.isHorse);
      const donkeys = details.horses.filter((h) => !h.isHorse);
      const avgHorseBCS =
        horses.length > 0
          ? (
              horses.reduce((sum, h) => sum + h.bcsScore, 0) / horses.length
            ).toFixed(1)
          : "";
      const avgDonkeyBCS =
        donkeys.length > 0
          ? (
              donkeys.reduce((sum, h) => sum + h.bcsScore, 0) / donkeys.length
            ).toFixed(1)
          : "";

      const nonCompliantSections = details.sections
        .map((section) => ({
          id: section.sectionNumber,
          title: section.title,
          subsections: section.subsections
            .map((sub) => ({
              name: sub.name,
              requirements: sub.requirements
                .filter((req) => req.complianceStatus === "Not Compliant")
                .map((req) => ({
                  text: req.text,
                  complianceStatus: req.complianceStatus || "",
                  findings: req.nonComplianceReason || undefined,
                })),
            }))
            .filter((sub) => sub.requirements.length > 0),
        }))
        .filter((section) => section.subsections.length > 0);

      const reportData = {
        metadata: {
          displayName: details.vetName,
          farmName: details.farmName,
          id: details.externalId,
          vetName: details.vetName,
          visitDate: new Date(details.visitDate).toLocaleDateString(),
          averageHorseBCS: avgHorseBCS,
          averageDonkeyBCS: avgDonkeyBCS,
        },
        nonCompliantFindings: {
          sections: nonCompliantSections,
        },
        sideNotes: details.sideNotes || "",
      };

      const reportDoc = generateDocument(reportData);
      const reportBlob = await Packer.toBlob(reportDoc);
      zip.file("assessment-report.docx", reportBlob);

      // 2. Generate horse table .docx
      const horseTableBlob = await generateHorseDoc(details.horses);
      zip.file("horse-table.docx", horseTableBlob);

      // A single failed media fetch shouldn't abort the whole export: collect
      // failures and still produce the zip with the report + everything that
      // did download. Never rejects.
      const failedFiles: string[] = [];
      const addRemoteFile = async (
        folder: JSZip,
        name: string,
        url: string
      ) => {
        try {
          const response = await fetch(url);
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          folder.file(name, await response.blob());
        } catch (err) {
          console.error(`Failed to fetch media "${name}":`, err);
          failedFiles.push(name);
        }
      };

      // 3. Add horse media folders. Sanitize and de-duplicate folder names so
      // same-named (or unnamed) horses don't overwrite each other's photos.
      const usedFolderNames = new Set<string>();
      for (const horse of media.horseMedia) {
        const base = sanitizeName(horse.horseName) || "unnamed-horse";
        let folderName = base;
        for (let n = 2; usedFolderNames.has(folderName); n++) {
          folderName = `${base}-${n}`;
        }
        usedFolderNames.add(folderName);

        const folder = zip.folder(folderName);
        if (!folder) continue;
        await Promise.all(
          horse.files.map((file) => addRemoteFile(folder, file.name, file.url))
        );
      }

      // 4. Add requirement media folder
      if (media.requirementMedia.length > 0) {
        const reqFolder = zip.folder("requirement-media");
        if (reqFolder) {
          await Promise.all(
            media.requirementMedia.map((file) =>
              addRemoteFile(reqFolder, file.name, file.url)
            )
          );
        }
      }

      // 5. Generate and download zip
      const zipBlob = await zip.generateAsync({ type: "blob" });
      saveAs(
        zipBlob,
        `${sanitizeName(assessment.farmName) || "assessment"}-assessment.zip`
      );

      if (failedFiles.length > 0) {
        alert(
          `Download complete, but ${failedFiles.length} media file(s) could not be retrieved and were skipped:\n${failedFiles.join("\n")}`
        );
      }
    } catch (error) {
      alert(
        `Download failed: ${error instanceof Error ? error.message : "Unknown error"}`
      );
    } finally {
      setDownloadingId(null);
    }
  };

  return (
    <div className="flex flex-col gap-6 w-11/12 max-w-3xl">
      <h2>Hey, {email ?? "there"}!</h2>
      <h2 className="font-medium text-xl mb-4">Your Assessments</h2>

      {assessments.length === 0 ? (
        <p className="text-gray-500">
          No assessments yet. Sync from the iOS app to see them here.
        </p>
      ) : (
        <div className="flex flex-wrap gap-3 justify-between">
          {assessments.map((assessment) => (
            <div
              key={assessment.id}
              className="flex justify-between shrink-1 basis-full md:basis-[47%] gap-2 hover:bg-slate-200 dark:hover:bg-slate-800 p-4 rounded-md border"
            >
              <div>
                <p className="font-medium">
                  {assessment.vetName} - {assessment.farmName}
                </p>
                <p className="text-sm text-gray-500">
                  {new Date(assessment.visitDate).toLocaleDateString()}
                </p>
                <p className="text-xs text-gray-400">
                  {assessment.isComplete ? "Complete" : "In Progress"}
                </p>
              </div>
              <div className="flex gap-2 items-start">
                <button
                  onClick={() => handleDownload(assessment)}
                  disabled={downloadingId === assessment.id}
                  className="border rounded-md py-2 px-4 h-min bg-none hover:bg-green-400 hover:text-green-800 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                  title="Download report"
                >
                  {downloadingId === assessment.id ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <Download className="w-4 h-4" />
                  )}
                </button>
                <button
                  onClick={() => handleDelete(assessment)}
                  className="border rounded-md py-2 px-4 h-min bg-none hover:bg-red-400 hover:text-red-800 transition-all"
                  title="Delete assessment"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
