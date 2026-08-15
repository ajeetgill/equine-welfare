/// <reference path="../pb_data/types.d.ts" />

// The original schema migration declared explicit field lists, which in
// PocketBase 0.23+ means the conventional `created`/`updated` autodate
// fields were never added. The dashboard sorts assessments by `-created`,
// so their absence made every list request fail with 400.
const COLLECTIONS = [
  "assessments",
  "horses",
  "sections",
  "subsections",
  "requirements",
  "media_attachments",
];

migrate((app) => {
  for (const name of COLLECTIONS) {
    const collection = app.findCollectionByNameOrId(name);
    collection.fields.add(new Field({ name: "created", type: "autodate", onCreate: true, onUpdate: false }));
    collection.fields.add(new Field({ name: "updated", type: "autodate", onCreate: true, onUpdate: true }));
    app.save(collection);
  }
}, (app) => {
  for (const name of COLLECTIONS) {
    const collection = app.findCollectionByNameOrId(name);
    collection.fields.removeByName("created");
    collection.fields.removeByName("updated");
    app.save(collection);
  }
});
