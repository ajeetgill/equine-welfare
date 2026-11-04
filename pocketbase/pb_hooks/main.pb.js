/// <reference path="../pb_data/types.d.ts" />

// Atomic port of the Convex assessments:syncAssessment mutation.
// Upserts an assessment by externalId; on re-sync, child horses/sections are
// wiped and re-inserted (subsections/requirements cascade via their relation
// fields). Media records are intentionally untouched — their externalIds are
// stable across syncs and uploads dedupe on them.
routerAdd("POST", "/api/equine/sync-assessment", (e) => {
  const body = e.requestInfo().body;
  const assessment = body.assessment;
  const horses = Array.isArray(body.horses) ? body.horses : [];
  const sections = Array.isArray(body.sections) ? body.sections : [];

  if (!assessment || typeof assessment.externalId !== "string" || assessment.externalId === "") {
    throw new BadRequestError("assessment.externalId is required");
  }

  let assessmentId = "";

  $app.runInTransaction((txApp) => {
    const assessmentsCol = txApp.findCollectionByNameOrId("assessments");

    let record = null;
    try {
      record = txApp.findFirstRecordByData("assessments", "externalId", assessment.externalId);
    } catch (_) {
      record = null; // first sync of this assessment
    }

    if (record) {
      const oldHorses = txApp.findRecordsByFilter("horses", "assessment = {:id}", "", 0, 0, { id: record.id });
      for (const h of oldHorses) txApp.delete(h);
      const oldSections = txApp.findRecordsByFilter("sections", "assessment = {:id}", "", 0, 0, { id: record.id });
      for (const s of oldSections) txApp.delete(s);
    } else {
      record = new Record(assessmentsCol);
      record.set("externalId", assessment.externalId);
    }

    record.set("vetName", assessment.vetName || "");
    record.set("farmName", assessment.farmName || "");
    record.set("visitDate", new Date(assessment.visitDate).toISOString());
    record.set("isComplete", !!assessment.isComplete);
    record.set("sideNotes", assessment.sideNotes || "");
    record.set("copVersion", assessment.copVersion || "");
    record.set("syncedAt", new Date().toISOString());
    record.set("uploadedBy", e.auth.id);
    txApp.save(record);
    assessmentId = record.id;

    const horsesCol = txApp.findCollectionByNameOrId("horses");
    for (const horse of horses) {
      const h = new Record(horsesCol);
      h.set("externalId", horse.externalId);
      h.set("assessment", assessmentId);
      h.set("name", horse.name || "");
      h.set("age", horse.age || 0);
      h.set("ageUnit", horse.ageUnit || "");
      h.set("color", horse.color || "");
      h.set("sex", horse.sex || "");
      h.set("breed", horse.breed || "");
      h.set("otherBreed", horse.otherBreed || "");
      h.set("timeOnFarm", horse.timeOnFarm || 0);
      h.set("timeUnit", horse.timeUnit || "");
      h.set("bcsScore", horse.bcsScore || 0);
      h.set("notes", horse.notes || "");
      h.set("isHorse", !!horse.isHorse);
      txApp.save(h);
    }

    const sectionsCol = txApp.findCollectionByNameOrId("sections");
    const subsectionsCol = txApp.findCollectionByNameOrId("subsections");
    const requirementsCol = txApp.findCollectionByNameOrId("requirements");
    for (const section of sections) {
      const s = new Record(sectionsCol);
      s.set("assessment", assessmentId);
      s.set("sectionNumber", section.sectionNumber || 0);
      s.set("title", section.title || "");
      s.set("isApplicable", !!section.isApplicable);
      s.set("infoIconClicks", section.infoIconClicks || 0);
      txApp.save(s);

      const subsections = Array.isArray(section.subsections) ? section.subsections : [];
      for (const subsection of subsections) {
        const sub = new Record(subsectionsCol);
        sub.set("section", s.id);
        sub.set("name", subsection.name || "");
        txApp.save(sub);

        const requirements = Array.isArray(subsection.requirements) ? subsection.requirements : [];
        for (const requirement of requirements) {
          const r = new Record(requirementsCol);
          r.set("subsection", sub.id);
          r.set("text", requirement.text || "");
          r.set("complianceStatus", requirement.complianceStatus || "");
          r.set("nonComplianceReason", requirement.nonComplianceReason || "");
          txApp.save(r);
        }
      }
    }
  });

  return e.json(200, { assessmentId: assessmentId });
}, $apis.requireAuth());
