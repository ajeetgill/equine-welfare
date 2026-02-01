# Convex Media Upload & Migration Gaps Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire up media upload during iOS sync, fix missing media deletion on assessment delete, and close remaining migration gaps.

**Architecture:** iOS `syncAssessment()` already uploads text data to Convex. The `uploadMedia()` function and backend mutations (`files:generateUploadUrl`, `files:saveFile`) exist but aren't called. We wire them together: after syncing text data, iterate over horse photos and requirement media, upload each via `uploadMedia()`, then save references via `files:saveFile`.

**Tech Stack:** Swift 6.1 (iOS), TypeScript (Convex backend), Next.js 15 (web frontend)

---

## Migration Gap Inventory

| Item | Severity | Status |
|---|---|---|
| Horse photo upload during sync | CRITICAL | Not wired |
| Requirement media upload during sync | CRITICAL | Not wired |
| Delete mutation misses media + storage files | HIGH | Not implemented |
| `getHorseMedia` query only checks `horse_photo` | MEDIUM | Incomplete — fixed by `getAssessmentMedia` added today |
| Web README still references Supabase | LOW | Cosmetic |

---

## Task 1: Wire Up Horse Photo Upload in iOS `syncToConvex()`

**Files:**
- Modify: `equine-welfare/PreviousAssessmentRow.swift:84-115`
- Modify: `equine-welfare/Services/ConvexService.swift:16-103`

**Context:** The `Horse_Model.swift` has 6 photo properties: `photoData`, `frontPhotoData`, `rightPhotoData`, `backPhotoData`, `leftPhotoData`, `abnormalPhotosData: [MediaAttachment]`. Each `MediaAttachment` has `id: UUID`, `data: Data`, `mediaType: MediaType`, `creationDate: Date`. The `ConvexService.uploadMedia()` at line 115 takes `data: Data`, `externalId: String`, `parentType: String`, `parentId: String`, `mediaType: String` and uploads to Convex storage.

**Step 1: Add horse media upload to `syncAssessment()` in ConvexService.swift**

After the existing `client.mutation("assessments:syncAssessment", ...)` call at line 96, add horse media upload loop:

```swift
progressHandler?("Uploading horse media...", 0.6)

let totalHorses = assessment.horses.count
for (index, horse) in assessment.horses.enumerated() {
    let horseId = horse.uuid.uuidString

    // Upload named photo views
    let namedPhotos: [(String, MediaAttachment?)] = [
        ("horse_photo", horse.photoData),
        ("horse_front", horse.frontPhotoData),
        ("horse_right", horse.rightPhotoData),
        ("horse_back", horse.backPhotoData),
        ("horse_left", horse.leftPhotoData),
    ]

    for (parentType, attachment) in namedPhotos {
        if let attachment = attachment {
            try await uploadMedia(
                data: attachment.data,
                externalId: attachment.id.uuidString,
                parentType: parentType,
                parentId: horseId,
                mediaType: attachment.mediaType.rawValue
            )
        }
    }

    // Upload abnormal photos (array)
    for attachment in horse.abnormalPhotosData {
        try await uploadMedia(
            data: attachment.data,
            externalId: attachment.id.uuidString,
            parentType: "horse_abnormal",
            parentId: horseId,
            mediaType: attachment.mediaType.rawValue
        )
    }

    let horseProgress = 0.6 + (Double(index + 1) / Double(totalHorses)) * 0.2
    progressHandler?("Uploading horse media (\(index + 1)/\(totalHorses))...", horseProgress)
}
```

**Step 2: Verify iOS build**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add equine-welfare/Services/ConvexService.swift
git commit -m "feat(ios): wire up horse photo upload during Convex sync

- Upload main, front, right, back, left photos for each horse
- Upload abnormal photos array for each horse
- Show per-horse progress during upload"
```

---

## Task 2: Wire Up Requirement Media Upload in iOS Sync

**Files:**
- Modify: `equine-welfare/Services/ConvexService.swift`

**Context:** `Requirement_Model.swift` has `mediaAttachments: [MediaAttachment]` relationship. These are photos/videos attached to compliance requirements. The requirement doesn't have its own externalId, but the subsection it belongs to can be identified. We use the requirement's text + subsection name as a composite identifier, or generate one. Simplest: use the assessment's externalId + section number + requirement index as parentId.

Actually, looking at the existing code: requirements don't have their own UUID in the Convex schema. The `parentId` for requirement media should reference something stable. Best approach: use the requirement's Convex `_id` after it's created. But `syncAssessment` is a single mutation — we'd need to return requirement IDs or restructure.

Simpler approach: use a composite key like `{assessmentExternalId}_{sectionNumber}_{subsectionIndex}_{requirementIndex}` as `parentId`, with `parentType: "requirement"`.

**Step 1: Add requirement media upload after horse media upload**

After the horse media loop from Task 1, add:

```swift
progressHandler?("Uploading requirement media...", 0.8)

for section in assessment.sections where section.isApplicable {
    for (subIdx, subsection) in section.subsections.enumerated() {
        for (reqIdx, requirement) in subsection.requirements.enumerated() {
            guard !requirement.mediaAttachments.isEmpty else { continue }

            let parentId = "\(assessment.id.uuidString)_\(section.id)_\(subIdx)_\(reqIdx)"

            for attachment in requirement.mediaAttachments {
                try await uploadMedia(
                    data: attachment.data,
                    externalId: attachment.id.uuidString,
                    parentType: "requirement",
                    parentId: parentId,
                    mediaType: attachment.mediaType.rawValue
                )
            }
        }
    }
}

progressHandler?("Sync complete!", 1.0)
```

**Step 2: Verify iOS build**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
git add equine-welfare/Services/ConvexService.swift
git commit -m "feat(ios): wire up requirement media upload during Convex sync

- Upload photos/videos attached to compliance requirements
- Use composite key for requirement identification"
```

---

## Task 3: Fix Delete Mutation to Clean Up Media + Storage

**Files:**
- Modify: `equine-frontend/convex/assessments.ts` (the `remove` mutation, lines ~224-266)

**Context:** Current `remove` mutation deletes sections, subsections, requirements, horses, and the assessment — but not `mediaAttachments` records or their actual files from Convex storage. This orphans storage files.

**Step 1: Update `remove` mutation to delete media**

Add before `// Delete assessment` (after deleting horses), insert:

```typescript
    // Delete media attachments and their storage files
    const horseExternalIds = horses.map(h => h.externalId);
    for (const horseId of horseExternalIds) {
      const media = await ctx.db
        .query("mediaAttachments")
        .withIndex("by_parent_id", (q) => q.eq("parentId", horseId))
        .collect();
      for (const m of media) {
        await ctx.storage.delete(m.storageId);
        await ctx.db.delete(m._id);
      }
    }

    // Delete requirement media (parentId starts with assessment externalId)
    const assessment = await ctx.db.get(args.id);
    if (assessment) {
      const allMedia = await ctx.db.query("mediaAttachments").collect();
      const reqMedia = allMedia.filter(m =>
        m.parentType === "requirement" && m.parentId.startsWith(assessment.externalId)
      );
      for (const m of reqMedia) {
        await ctx.storage.delete(m.storageId);
        await ctx.db.delete(m._id);
      }
    }
```

**Step 2: Deploy and verify build**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && nvm use node && npx next build 2>&1 | tail -5
```

**Step 3: Commit**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && git add equine-frontend/convex/assessments.ts
git commit -m "fix(convex): delete media attachments and storage files on assessment removal

- Delete horse media by looking up parentId via by_parent_id index
- Delete requirement media by filtering on assessment externalId prefix
- Delete actual storage files via ctx.storage.delete()"
```

---

## Task 4: Verify End-to-End Flow

**Step 1: Push Convex schema changes**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npx convex dev --once
```

This deploys the `by_parent_id` index added earlier and any mutation updates.

**Step 2: Build iOS app**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5
```

**Step 3: Build web app**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && nvm use node && npm run build 2>&1 | tail -5
```

**Step 4: Manual test checklist**

1. On iPad, create or open an assessment with horse photos
2. Tap Sync → confirm assessment syncs AND shows media upload progress
3. On web app, click Download → confirm zip contains:
   - `assessment-report.docx`
   - `horse-table.docx`
   - `{HorseName}/front.jpg`, `right.jpg`, etc. (if photos were taken)
4. On web app, click Delete → confirm assessment + media are removed
5. Check Convex dashboard → verify no orphaned storage files

**Step 5: Commit milestone**

```bash
git commit --allow-empty -m "milestone: media upload wiring complete — full sync flow operational"
```
