import { RecordModel } from "pocketbase";
import { getPocketBase } from "./pocketbase";

export interface AssessmentRecord extends RecordModel {
  externalId: string;
  vetName: string;
  farmName: string;
  visitDate: string; // ISO date string from PocketBase
  isComplete: boolean;
  sideNotes: string;
  syncedAt: string;
}

export interface HorseRecord extends RecordModel {
  externalId: string;
  assessment: string;
  name: string;
  age: number;
  ageUnit: string;
  color: string;
  sex: string;
  breed: string;
  otherBreed: string;
  timeOnFarm: number;
  timeUnit: string;
  bcsScore: number;
  notes: string;
  isHorse: boolean;
}

export interface SectionRecord extends RecordModel {
  assessment: string;
  sectionNumber: number;
  title: string;
  isApplicable: boolean;
  infoIconClicks: number;
}

export interface SubsectionRecord extends RecordModel {
  section: string;
  name: string;
}

export interface RequirementRecord extends RecordModel {
  subsection: string;
  text: string;
  complianceStatus: string;
  nonComplianceReason: string;
}

export interface MediaRecord extends RecordModel {
  externalId: string;
  parentType: string;
  parentId: string;
  assessmentExternalId: string;
  file: string;
  mediaType: string;
  creationDate: string;
}

export interface AssessmentDetails extends AssessmentRecord {
  horses: HorseRecord[];
  sections: (SectionRecord & {
    subsections: (SubsectionRecord & { requirements: RequirementRecord[] })[];
  })[];
}

// Port of the Convex getWithDetails fan-out: one query per collection using
// relation-traversal filters, then stitched together in memory.
export async function fetchAssessmentDetails(id: string): Promise<AssessmentDetails> {
  const pb = getPocketBase();
  const [assessment, horses, sections, subsections, requirements] = await Promise.all([
    pb.collection("assessments").getOne<AssessmentRecord>(id),
    pb.collection("horses").getFullList<HorseRecord>({
      filter: pb.filter("assessment = {:id}", { id }),
    }),
    pb.collection("sections").getFullList<SectionRecord>({
      filter: pb.filter("assessment = {:id}", { id }),
      sort: "sectionNumber",
    }),
    pb.collection("subsections").getFullList<SubsectionRecord>({
      filter: pb.filter("section.assessment = {:id}", { id }),
    }),
    pb.collection("requirements").getFullList<RequirementRecord>({
      filter: pb.filter("subsection.section.assessment = {:id}", { id }),
    }),
  ]);

  const reqsBySubsection = new Map<string, RequirementRecord[]>();
  for (const req of requirements) {
    const list = reqsBySubsection.get(req.subsection) ?? [];
    list.push(req);
    reqsBySubsection.set(req.subsection, list);
  }

  const subsBySection = new Map<string, (SubsectionRecord & { requirements: RequirementRecord[] })[]>();
  for (const sub of subsections) {
    const withReqs = { ...sub, requirements: reqsBySubsection.get(sub.id) ?? [] };
    const list = subsBySection.get(sub.section) ?? [];
    list.push(withReqs);
    subsBySection.set(sub.section, list);
  }

  return {
    ...assessment,
    horses,
    sections: sections.map((s) => ({ ...s, subsections: subsBySection.get(s.id) ?? [] })),
  };
}

export interface MediaFiles {
  horseMedia: { horseName: string; files: { name: string; url: string }[] }[];
  requirementMedia: { name: string; url: string }[];
}

// Port of the Convex getAssessmentMedia query. One indexed query on
// assessmentExternalId (the old version full-scanned the table), then file
// URLs with a short-lived file token (the file field is protected).
export async function fetchAssessmentMedia(
  assessment: AssessmentRecord,
  horses: HorseRecord[]
): Promise<MediaFiles> {
  const pb = getPocketBase();
  const media = await pb.collection("media_attachments").getFullList<MediaRecord>({
    filter: pb.filter("assessmentExternalId = {:ext}", { ext: assessment.externalId }),
    sort: "creationDate",
  });
  const fileToken = await pb.files.getToken();

  const horsesByExternalId = new Map(horses.map((h) => [h.externalId, h]));
  const horseFiles = new Map<string, { name: string; url: string }[]>();
  const requirementMedia: { name: string; url: string }[] = [];
  const abnormalCounts = new Map<string, number>();

  for (const att of media) {
    const url = pb.files.getURL(att, att.file, { token: fileToken });
    const ext = att.mediaType === "video" ? "mp4" : "jpg";

    if (att.parentType === "requirement") {
      requirementMedia.push({
        name: `requirement_${requirementMedia.length + 1}.${ext}`,
        url,
      });
      continue;
    }
    if (!att.parentType.startsWith("horse_")) continue;
    if (!horsesByExternalId.has(att.parentId)) continue;

    const photoType = att.parentType.replace("horse_", "");
    let name: string;
    if (photoType === "abnormal") {
      const n = (abnormalCounts.get(att.parentId) ?? 0) + 1;
      abnormalCounts.set(att.parentId, n);
      name = `abnormal_${n}.${ext}`;
    } else {
      name = `${photoType}.${ext}`;
    }
    const list = horseFiles.get(att.parentId) ?? [];
    list.push({ name, url });
    horseFiles.set(att.parentId, list);
  }

  const horseMedia = Array.from(horseFiles.entries()).map(([parentId, files]) => ({
    horseName: horsesByExternalId.get(parentId)?.name || "unnamed-horse",
    files,
  }));

  return { horseMedia, requirementMedia };
}

// Port of the Convex remove mutation. Media records have no relation to
// assessments (they survive re-syncs by design), so they're deleted by the
// indexed assessmentExternalId query; PocketBase deletes their stored files
// with the records. Everything else cascades off the assessment via
// relation cascadeDelete.
export async function deleteAssessmentCascade(assessment: AssessmentRecord): Promise<void> {
  const pb = getPocketBase();
  const media = await pb.collection("media_attachments").getFullList<MediaRecord>({
    filter: pb.filter("assessmentExternalId = {:ext}", { ext: assessment.externalId }),
  });
  for (const m of media) {
    await pb.collection("media_attachments").delete(m.id);
  }
  await pb.collection("assessments").delete(assessment.id);
}
