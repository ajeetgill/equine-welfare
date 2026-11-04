/// <reference path="../pb_data/types.d.ts" />

// Assessments now carry the Code of Practice edition they were created
// against (e.g. "2013"), stamped by the iOS app and shown on the dashboard
// and in the docx report. Plain optional text — records synced by older app
// builds simply leave it empty (they all predate the next edition anyway).
migrate((app) => {
  const collection = app.findCollectionByNameOrId("assessments");
  collection.fields.add(new Field({ name: "copVersion", type: "text" }));
  app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("assessments");
  collection.fields.removeByName("copVersion");
  app.save(collection);
});
