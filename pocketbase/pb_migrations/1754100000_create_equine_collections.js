/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const authRule = '@request.auth.id != ""';
  const usersId = app.findCollectionByNameOrId("users").id;

  // No self-registration: only superusers create accounts.
  const users = app.findCollectionByNameOrId("users");
  users.createRule = null;
  app.save(users);

  const assessments = new Collection({
    type: "base",
    name: "assessments",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "externalId", type: "text", required: true },
      { name: "vetName", type: "text" },
      { name: "farmName", type: "text" },
      { name: "visitDate", type: "date" },
      { name: "isComplete", type: "bool" },
      { name: "sideNotes", type: "text" },
      { name: "syncedAt", type: "date" },
      { name: "uploadedBy", type: "relation", collectionId: usersId, maxSelect: 1, cascadeDelete: false },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_assessments_externalId ON assessments (externalId)"],
  });
  app.save(assessments);

  const horses = new Collection({
    type: "base",
    name: "horses",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "externalId", type: "text", required: true },
      { name: "assessment", type: "relation", collectionId: assessments.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "name", type: "text" },
      { name: "age", type: "number" },
      { name: "ageUnit", type: "text" },
      { name: "color", type: "text" },
      { name: "sex", type: "text" },
      { name: "breed", type: "text" },
      { name: "otherBreed", type: "text" },
      { name: "timeOnFarm", type: "number" },
      { name: "timeUnit", type: "text" },
      { name: "bcsScore", type: "number" },
      { name: "notes", type: "text" },
      { name: "isHorse", type: "bool" },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_horses_externalId ON horses (externalId)"],
  });
  app.save(horses);

  const sections = new Collection({
    type: "base",
    name: "sections",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "assessment", type: "relation", collectionId: assessments.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "sectionNumber", type: "number" },
      { name: "title", type: "text" },
      { name: "isApplicable", type: "bool" },
      { name: "infoIconClicks", type: "number" },
    ],
  });
  app.save(sections);

  const subsections = new Collection({
    type: "base",
    name: "subsections",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "section", type: "relation", collectionId: sections.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "name", type: "text" },
    ],
  });
  app.save(subsections);

  const requirements = new Collection({
    type: "base",
    name: "requirements",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "subsection", type: "relation", collectionId: subsections.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "text", type: "text" },
      { name: "complianceStatus", type: "text" },
      { name: "nonComplianceReason", type: "text" },
    ],
  });
  app.save(requirements);

  const media = new Collection({
    type: "base",
    name: "media_attachments",
    listRule: authRule, viewRule: authRule,
    createRule: authRule, updateRule: authRule, deleteRule: authRule,
    fields: [
      { name: "externalId", type: "text", required: true },
      {
        name: "parentType", type: "select", maxSelect: 1, required: true,
        values: ["horse_photo", "horse_front", "horse_right", "horse_back", "horse_left", "horse_abnormal", "requirement"],
      },
      { name: "parentId", type: "text", required: true },
      { name: "assessmentExternalId", type: "text", required: true },
      {
        name: "file", type: "file", maxSelect: 1, required: true, protected: true,
        maxSize: 104857600,
        mimeTypes: ["image/jpeg", "image/png", "image/heic", "video/mp4"],
      },
      { name: "mediaType", type: "select", maxSelect: 1, values: ["image", "video"] },
      { name: "creationDate", type: "date" },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_media_externalId ON media_attachments (externalId)",
      "CREATE INDEX idx_media_assessmentExternalId ON media_attachments (assessmentExternalId)",
    ],
  });
  app.save(media);
}, (app) => {
  for (const name of ["media_attachments", "requirements", "subsections", "sections", "horses", "assessments"]) {
    try { app.delete(app.findCollectionByNameOrId(name)); } catch (_) { /* already gone */ }
  }
  const users = app.findCollectionByNameOrId("users");
  users.createRule = "";
  app.save(users);
});
