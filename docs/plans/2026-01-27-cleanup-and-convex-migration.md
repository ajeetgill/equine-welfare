# Cleanup and Clerk + Convex Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Clean up both iOS and web codebases, then replace Supabase with Clerk (auth) + Convex (database + file storage).

**Architecture:**
- iOS app: SwiftData remains local-first source of truth. Add Convex Swift SDK for on-click sync to cloud.
- Web app: Replace Supabase Auth with Clerk. Replace Supabase Storage queries with Convex DB queries.
- Convex backend: Define schema mirroring SwiftData models. Handle file storage for media.

**Tech Stack:**
- iOS: Swift 6.1, SwiftUI, SwiftData, Convex Swift SDK
- Web: Next.js 15, React 19, TypeScript, Clerk, Convex
- Backend: Convex (database + file storage)

---

## Phase 1: Code Cleanup

### Task 1: Create Feature Branch

**Files:**
- None (git operation)

**Step 1: Create and checkout new branch**

```bash
git checkout -b cleanup-and-convex-migration
```

**Step 2: Verify branch**

```bash
git branch --show-current
```

Expected: `cleanup-and-convex-migration`

---

### Task 2: Fix Security Issue - Remove Hardcoded Credentials from HorseService

**Files:**
- Modify: `equine-welfare/Services/HorseService.swift:1-14`

**Step 1: Remove hardcoded Supabase credentials and unused imports**

Replace lines 1-14:

```swift
import SwiftData
import Foundation
import Supabase

class HorseService {

    private static let supabaseURL = URL(string: "https://aknlkmbwbbnfxaoqljzd.supabase.co")!
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrbmxrbWJ3YmJuZnhhb3FsanpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEzOTEyMTQsImV4cCI6MjA1Njk2NzIxNH0.kjZRF_JwWN9ovTahZFmGcj9h6XgIhApWTVCrAA6o8ZQ"

    // Create a Supabase client instance
    private static let supabase = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseKey
    )
```

With:

```swift
import SwiftData
import Foundation

class HorseService {
```

**Step 2: Remove dead code - sendHorses method and Supabase upload methods**

Delete lines 74-186 (the `sendHorses`, `uploadHorsesToSupabase`, and `uploadHorsesForAssessment` methods).

Keep only `fetchHorses` and `encodeHorsesToJSON` methods.

**Step 3: Verify file compiles**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | head -50
```

Note: Build will fail because SupabaseService still calls HorseService methods. This is expected - we'll fix in Task 3.

**Step 4: Commit security fix**

```bash
git add equine-welfare/Services/HorseService.swift
git commit -m "fix(security): remove hardcoded Supabase credentials from HorseService

- Remove exposed API key from source code
- Remove unused Supabase import
- Remove dead code (sendHorses, uploadHorsesToSupabase, uploadHorsesForAssessment)
- Keep fetchHorses and encodeHorsesToJSON utilities"
```

---

### Task 3: Update SupabaseService to Not Depend on HorseService

**Files:**
- Modify: `equine-welfare/Utils/SupabaseService.swift:476-491`

**Step 1: Remove HorseService call from uploadAssessmentComplete**

Find and remove lines 476-491 (the horse upload step):

```swift
            // Step 1: Upload horse data via HorseService
            progressHandler?("Uploading horse data...", 0.1)

            // Instead of just calling HorseService.sendHorses which posts to an API endpoint,
            // use our new method to upload horse data as a JSON file
            let horseUploadResult = await HorseService.uploadHorsesForAssessment(
                modelContext: modelContext,
                assessmentName: assessment.displayName,
                assessmentId: assessment.id
            )

            if case .failure(let error) = horseUploadResult {
                print("Warning: Horse data upload failed: \(error.localizedDescription)")
                // Continue with the rest of the uploads even if this one failed
            }
```

Replace with inline horse JSON upload (using SupabaseService's own client):

```swift
            // Step 1: Upload horse data as JSON
            progressHandler?("Uploading horse data...", 0.1)

            let horses = assessment.horses
            let horseDicts = horses.map { horse -> [String: Any] in
                var dict: [String: Any] = [
                    "uuid": horse.uuid.uuidString,
                    "name": horse.name,
                    "age": horse.age,
                    "color": horse.color,
                    "sex": horse.sex,
                    "breed": horse.breed,
                    "timeOnFarm": horse.timeOnFarm,
                    "bcsScore": horse.bcsScore,
                    "ageUnit": horse.ageUnit.rawValue,
                    "timeUnit": horse.timeUnit.rawValue,
                    "isHorse": horse.isHorse
                ]
                if let otherBreed = horse.otherBreed { dict["otherBreed"] = otherBreed }
                if let notes = horse.notes { dict["notes"] = notes }
                return dict
            }

            if let jsonData = try? JSONSerialization.data(withJSONObject: horseDicts, options: .prettyPrinted) {
                let sanitizedFolderName = assessment.displayName.replacingOccurrences(of: "/", with: "-")
                let storagePath = "\(sanitizedFolderName)/horses/horse_data.json"

                do {
                    _ = try await client.storage
                        .from("assessments")
                        .upload(path: storagePath, file: jsonData, options: FileOptions(contentType: "application/json"))
                } catch {
                    print("Warning: Horse data upload failed: \(error.localizedDescription)")
                }
            }
```

**Step 2: Remove HorseService import if present**

Check top of file - there's no explicit import since they're in same module, but verify no reference remains.

**Step 3: Verify build succeeds**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add equine-welfare/Utils/SupabaseService.swift
git commit -m "refactor: inline horse upload logic in SupabaseService

- Remove dependency on HorseService.uploadHorsesForAssessment
- Inline horse JSON serialization directly in uploadAssessmentComplete
- Prepares for HorseService cleanup"
```

---

### Task 4: Remove Debug Print Statements from SupabaseService

**Files:**
- Modify: `equine-welfare/Utils/SupabaseService.swift`

**Step 1: Remove all debug print statements**

Remove these print statements throughout the file:
- Line 47-48: `print("Debug - Supabase Credentials Check: ...")`
- Line 64: `print("Starting RTF document upload for: ...")`
- Line 68: `print("Error: RTF file does not exist...")`
- Line 88: `print("Successfully read RTF file data...")`
- Line 99: `print("RTF document uploaded successfully...")`
- Line 104: `print("Error uploading RTF document...")`
- Line 126: `print("Starting JSON data upload for...")`
- Line 164: `print("JSON data uploaded successfully...")`
- Line 169: `print("Error uploading JSON data...")`
- Line 235: `print("Uploading media file...")`
- Line 255: `print("Error uploading media attachment...")`
- Line 270: `print("Error in upload process...")`
- And all other print statements in the file

**Step 2: Verify build**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -10
```

**Step 3: Commit**

```bash
git add equine-welfare/Utils/SupabaseService.swift
git commit -m "chore: remove debug print statements from SupabaseService"
```

---

### Task 5: Remove Debug Print from HorseService

**Files:**
- Modify: `equine-welfare/Services/HorseService.swift`

**Step 1: Remove print statement**

Remove line 29: `print("Error fetching horses: \(error)")`

Replace the catch block with just returning empty array:

```swift
        } catch {
            return []
        }
```

**Step 2: Remove print from encodeHorsesToJSON**

Remove line 69-70: `print("Error encoding horses to JSON: \(error)")`

**Step 3: Commit**

```bash
git add equine-welfare/Services/HorseService.swift
git commit -m "chore: remove debug print statements from HorseService"
```

---

### Task 6: Remove Debug Print from PreviousAssessmentRow

**Files:**
- Modify: `equine-welfare/PreviousAssessmentRow.swift`

**Step 1: Remove print statements**

Remove line 77-78: `print("Error converting to RTF format")`
Remove line 80: `print("Error creating share file: \(error.localizedDescription)")`

**Step 2: Commit**

```bash
git add equine-welfare/PreviousAssessmentRow.swift
git commit -m "chore: remove debug print statements from PreviousAssessmentRow"
```

---

### Task 7: Web App Cleanup - Remove Commented Debug Code

**Files:**
- Modify: `equine-frontend/actions/supabase.ts`

**Step 1: Remove commented-out debug code**

Remove lines 52-53:
```typescript
// filePath.includes("json") && console.log("DONWLOAD FILE, filepath: ", filePath);
// console.log("DONWLOAD FILE, filetype: ", data);
```

Remove lines 73-82 (commented-out downloadFolder function):
```typescript
// Download a folder by redirecting to the API
// export const downloadFolder = (folderName: string) => {
//   const url = `/api/download/${folderName}`;
//   window.open(url, "_blank");
//   return true;
// };
```

**Step 2: Commit**

```bash
git add equine-frontend/actions/supabase.ts
git commit -m "chore(web): remove commented-out debug code from supabase.ts"
```

---

### Task 8: Web App Cleanup - Fix Toast Memory Leak

**Files:**
- Modify: `equine-frontend/hooks/use-toast.ts`

**Step 1: Fix unreasonable toast removal delay**

Change line 9 from:
```typescript
const TOAST_REMOVE_DELAY = 1000000
```

To:
```typescript
const TOAST_REMOVE_DELAY = 5000
```

**Step 2: Commit**

```bash
git add equine-frontend/hooks/use-toast.ts
git commit -m "fix(web): reduce toast removal delay from 278 hours to 5 seconds"
```

---

### Task 9: Phase 1 Verification - Build Both Apps

**Step 1: Build iOS app**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`

**Step 2: Build web app**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npm run build
```

Expected: Build succeeds

**Step 3: Commit phase completion marker**

```bash
git commit --allow-empty -m "milestone: Phase 1 complete - code cleanup done"
```

---

## Phase 2: Convex Backend Setup

### Task 10: Initialize Convex Project

**Files:**
- Create: `convex/` directory structure

**Step 1: Install Convex in web frontend**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npm install convex
```

**Step 2: Initialize Convex**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npx convex dev --once
```

Follow prompts to connect to your existing Convex project.

**Step 3: Commit**

```bash
git add equine-frontend/package.json equine-frontend/package-lock.json equine-frontend/convex/
git commit -m "feat: initialize Convex in web frontend"
```

---

### Task 11: Define Convex Schema

**Files:**
- Create: `equine-frontend/convex/schema.ts`

**Step 1: Create schema matching SwiftData models**

```typescript
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  assessments: defineTable({
    // Matches Assessment_Model.swift
    externalId: v.string(), // UUID from iOS
    vetName: v.string(),
    farmName: v.string(),
    visitDate: v.number(), // Unix timestamp
    isComplete: v.boolean(),
    sideNotes: v.optional(v.string()),
    syncedAt: v.number(), // When synced to Convex
  }).index("by_external_id", ["externalId"]),

  horses: defineTable({
    // Matches Horse_Model.swift
    externalId: v.string(), // UUID from iOS
    assessmentId: v.id("assessments"),
    name: v.string(),
    age: v.number(),
    color: v.string(),
    sex: v.string(),
    breed: v.string(),
    otherBreed: v.optional(v.string()),
    timeOnFarm: v.number(),
    bcsScore: v.number(),
    notes: v.optional(v.string()),
    ageUnit: v.string(), // "years" | "months" | "weeks" | "days"
    timeUnit: v.string(),
    isHorse: v.boolean(),
  }).index("by_assessment", ["assessmentId"])
    .index("by_external_id", ["externalId"]),

  sections: defineTable({
    // Matches Section_Model.swift
    assessmentId: v.id("assessments"),
    sectionNumber: v.number(), // 'id' in Swift model
    title: v.string(),
    isApplicable: v.boolean(),
    infoIconClicks: v.number(),
  }).index("by_assessment", ["assessmentId"]),

  subsections: defineTable({
    // Matches Subsection_Model.swift
    sectionId: v.id("sections"),
    name: v.string(),
  }).index("by_section", ["sectionId"]),

  requirements: defineTable({
    // Matches Requirement_Model.swift
    subsectionId: v.id("subsections"),
    text: v.string(),
    complianceStatus: v.optional(v.string()), // "Compliant" | "Not Compliant" | "N/A"
    nonComplianceReason: v.optional(v.string()),
  }).index("by_subsection", ["subsectionId"]),

  mediaAttachments: defineTable({
    // Matches MediaAttachment.swift
    externalId: v.string(), // UUID from iOS
    // Parent can be requirement or horse - use discriminated union
    parentType: v.string(), // "requirement" | "horse_photo" | "horse_front" | "horse_right" | "horse_back" | "horse_left" | "horse_abnormal"
    parentId: v.string(), // ID of parent (requirement or horse)
    storageId: v.id("_storage"), // Convex file storage ID
    mediaType: v.string(), // "image" | "video"
    creationDate: v.number(),
  }).index("by_parent", ["parentType", "parentId"]),
});
```

**Step 2: Deploy schema**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npx convex dev --once
```

**Step 3: Commit**

```bash
git add equine-frontend/convex/schema.ts
git commit -m "feat: define Convex schema mirroring SwiftData models"
```

---

### Task 12: Create Convex Mutations for Syncing

**Files:**
- Create: `equine-frontend/convex/assessments.ts`

**Step 1: Create sync mutation**

```typescript
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// Sync a complete assessment from iOS
export const syncAssessment = mutation({
  args: {
    assessment: v.object({
      externalId: v.string(),
      vetName: v.string(),
      farmName: v.string(),
      visitDate: v.number(),
      isComplete: v.boolean(),
      sideNotes: v.optional(v.string()),
    }),
    horses: v.array(v.object({
      externalId: v.string(),
      name: v.string(),
      age: v.number(),
      color: v.string(),
      sex: v.string(),
      breed: v.string(),
      otherBreed: v.optional(v.string()),
      timeOnFarm: v.number(),
      bcsScore: v.number(),
      notes: v.optional(v.string()),
      ageUnit: v.string(),
      timeUnit: v.string(),
      isHorse: v.boolean(),
    })),
    sections: v.array(v.object({
      sectionNumber: v.number(),
      title: v.string(),
      isApplicable: v.boolean(),
      infoIconClicks: v.number(),
      subsections: v.array(v.object({
        name: v.string(),
        requirements: v.array(v.object({
          text: v.string(),
          complianceStatus: v.optional(v.string()),
          nonComplianceReason: v.optional(v.string()),
        })),
      })),
    })),
  },
  handler: async (ctx, args) => {
    // Check if assessment already exists
    const existing = await ctx.db
      .query("assessments")
      .withIndex("by_external_id", (q) => q.eq("externalId", args.assessment.externalId))
      .first();

    if (existing) {
      throw new Error("Assessment already synced. Duplicate uploads not allowed.");
    }

    // Create assessment
    const assessmentId = await ctx.db.insert("assessments", {
      ...args.assessment,
      syncedAt: Date.now(),
    });

    // Create horses
    for (const horse of args.horses) {
      await ctx.db.insert("horses", {
        ...horse,
        assessmentId,
      });
    }

    // Create sections, subsections, requirements
    for (const section of args.sections) {
      const sectionId = await ctx.db.insert("sections", {
        assessmentId,
        sectionNumber: section.sectionNumber,
        title: section.title,
        isApplicable: section.isApplicable,
        infoIconClicks: section.infoIconClicks,
      });

      for (const subsection of section.subsections) {
        const subsectionId = await ctx.db.insert("subsections", {
          sectionId,
          name: subsection.name,
        });

        for (const requirement of subsection.requirements) {
          await ctx.db.insert("requirements", {
            subsectionId,
            text: requirement.text,
            complianceStatus: requirement.complianceStatus,
            nonComplianceReason: requirement.nonComplianceReason,
          });
        }
      }
    }

    return assessmentId;
  },
});

// List all assessments
export const list = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query("assessments").order("desc").collect();
  },
});

// Get assessment with all related data
export const getWithDetails = query({
  args: { id: v.id("assessments") },
  handler: async (ctx, args) => {
    const assessment = await ctx.db.get(args.id);
    if (!assessment) return null;

    const horses = await ctx.db
      .query("horses")
      .withIndex("by_assessment", (q) => q.eq("assessmentId", args.id))
      .collect();

    const sections = await ctx.db
      .query("sections")
      .withIndex("by_assessment", (q) => q.eq("assessmentId", args.id))
      .collect();

    // Get subsections and requirements for each section
    const sectionsWithDetails = await Promise.all(
      sections.map(async (section) => {
        const subsections = await ctx.db
          .query("subsections")
          .withIndex("by_section", (q) => q.eq("sectionId", section._id))
          .collect();

        const subsectionsWithReqs = await Promise.all(
          subsections.map(async (subsection) => {
            const requirements = await ctx.db
              .query("requirements")
              .withIndex("by_subsection", (q) => q.eq("subsectionId", subsection._id))
              .collect();
            return { ...subsection, requirements };
          })
        );

        return { ...section, subsections: subsectionsWithReqs };
      })
    );

    return { ...assessment, horses, sections: sectionsWithDetails };
  },
});

// Delete assessment and all related data
export const remove = mutation({
  args: { id: v.id("assessments") },
  handler: async (ctx, args) => {
    // Delete in reverse order of dependencies
    const sections = await ctx.db
      .query("sections")
      .withIndex("by_assessment", (q) => q.eq("assessmentId", args.id))
      .collect();

    for (const section of sections) {
      const subsections = await ctx.db
        .query("subsections")
        .withIndex("by_section", (q) => q.eq("sectionId", section._id))
        .collect();

      for (const subsection of subsections) {
        const requirements = await ctx.db
          .query("requirements")
          .withIndex("by_subsection", (q) => q.eq("subsectionId", subsection._id))
          .collect();

        for (const req of requirements) {
          await ctx.db.delete(req._id);
        }
        await ctx.db.delete(subsection._id);
      }
      await ctx.db.delete(section._id);
    }

    // Delete horses
    const horses = await ctx.db
      .query("horses")
      .withIndex("by_assessment", (q) => q.eq("assessmentId", args.id))
      .collect();

    for (const horse of horses) {
      await ctx.db.delete(horse._id);
    }

    // Delete media attachments
    const media = await ctx.db.query("mediaAttachments").collect();
    // Note: Would need to filter by assessment - simplified for now

    // Delete assessment
    await ctx.db.delete(args.id);
  },
});
```

**Step 2: Deploy**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npx convex dev --once
```

**Step 3: Commit**

```bash
git add equine-frontend/convex/assessments.ts
git commit -m "feat: add Convex mutations for assessment sync"
```

---

### Task 13: Create Convex File Upload Mutation

**Files:**
- Create: `equine-frontend/convex/files.ts`

**Step 1: Create file upload mutation**

```typescript
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// Generate upload URL for client
export const generateUploadUrl = mutation({
  args: {},
  handler: async (ctx) => {
    return await ctx.storage.generateUploadUrl();
  },
});

// Save file reference after upload
export const saveFile = mutation({
  args: {
    storageId: v.id("_storage"),
    externalId: v.string(),
    parentType: v.string(),
    parentId: v.string(),
    mediaType: v.string(),
    creationDate: v.number(),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("mediaAttachments", args);
  },
});

// Get file URL
export const getUrl = query({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, args) => {
    return await ctx.storage.getUrl(args.storageId);
  },
});

// Get all media for an assessment's horses
export const getHorseMedia = query({
  args: { horseExternalId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("mediaAttachments")
      .withIndex("by_parent", (q) =>
        q.eq("parentType", "horse_photo").eq("parentId", args.horseExternalId)
      )
      .collect();
  },
});
```

**Step 2: Deploy**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npx convex dev --once
```

**Step 3: Commit**

```bash
git add equine-frontend/convex/files.ts
git commit -m "feat: add Convex file storage mutations"
```

---

### Task 14: Configure Clerk with Convex

**Files:**
- Create: `equine-frontend/convex/auth.config.ts`

**Step 1: Create auth config**

```typescript
export default {
  providers: [
    {
      domain: process.env.CLERK_JWT_ISSUER_DOMAIN,
      applicationID: "convex",
    },
  ],
};
```

**Step 2: Add environment variable**

Create or update `.env.local`:

```bash
echo "CLERK_JWT_ISSUER_DOMAIN=your-clerk-frontend-api-url" >> equine-frontend/.env.local
```

Note: Get actual value from Clerk Dashboard > JWT Templates > Convex > Issuer URL

**Step 3: Commit config (not .env.local)**

```bash
git add equine-frontend/convex/auth.config.ts
git commit -m "feat: configure Clerk authentication with Convex"
```

---

## Phase 3: Web App Migration (Clerk + Convex)

### Task 15: Install Clerk Dependencies

**Files:**
- Modify: `equine-frontend/package.json`

**Step 1: Install Clerk**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npm install @clerk/nextjs
```

**Step 2: Commit**

```bash
git add equine-frontend/package.json equine-frontend/package-lock.json
git commit -m "feat(web): install Clerk SDK"
```

---

### Task 16: Create Convex + Clerk Provider

**Files:**
- Create: `equine-frontend/components/providers.tsx`

**Step 1: Create provider component**

```tsx
"use client";

import { ClerkProvider, useAuth } from "@clerk/nextjs";
import { ConvexProviderWithClerk } from "convex/react-clerk";
import { ConvexReactClient } from "convex/react";
import { ReactNode } from "react";

const convex = new ConvexReactClient(process.env.NEXT_PUBLIC_CONVEX_URL!);

export function Providers({ children }: { children: ReactNode }) {
  return (
    <ClerkProvider>
      <ConvexProviderWithClerk client={convex} useAuth={useAuth}>
        {children}
      </ConvexProviderWithClerk>
    </ClerkProvider>
  );
}
```

**Step 2: Commit**

```bash
git add equine-frontend/components/providers.tsx
git commit -m "feat(web): create Convex + Clerk provider component"
```

---

### Task 17: Update Root Layout with Providers

**Files:**
- Modify: `equine-frontend/app/layout.tsx`

**Step 1: Wrap app with providers**

Update the layout to use the new providers:

```tsx
import { Providers } from "@/components/providers";
// ... other imports

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <Providers>
          {/* existing content */}
          {children}
        </Providers>
      </body>
    </html>
  );
}
```

**Step 2: Commit**

```bash
git add equine-frontend/app/layout.tsx
git commit -m "feat(web): integrate Clerk + Convex providers in layout"
```

---

### Task 18: Create Clerk Middleware

**Files:**
- Modify: `equine-frontend/middleware.ts`

**Step 1: Replace Supabase middleware with Clerk**

```typescript
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isProtectedRoute = createRouteMatcher(["/protected(.*)"]);

export default clerkMiddleware(async (auth, req) => {
  if (isProtectedRoute(req)) {
    await auth.protect();
  }
});

export const config = {
  matcher: [
    "/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)",
    "/(api|trpc)(.*)",
  ],
};
```

**Step 2: Commit**

```bash
git add equine-frontend/middleware.ts
git commit -m "feat(web): replace Supabase auth middleware with Clerk"
```

---

### Task 19: Update Auth Pages for Clerk

**Files:**
- Modify: `equine-frontend/app/(auth-pages)/sign-in/page.tsx`
- Modify: `equine-frontend/app/(auth-pages)/sign-up/page.tsx`

**Step 1: Update sign-in page**

```tsx
import { SignIn } from "@clerk/nextjs";

export default function SignInPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignIn afterSignInUrl="/protected" />
    </div>
  );
}
```

**Step 2: Update sign-up page**

```tsx
import { SignUp } from "@clerk/nextjs";

export default function SignUpPage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <SignUp afterSignUpUrl="/protected" />
    </div>
  );
}
```

**Step 3: Commit**

```bash
git add equine-frontend/app/\(auth-pages\)/
git commit -m "feat(web): update auth pages to use Clerk components"
```

---

### Task 20: Update Protected Page to Use Convex

**Files:**
- Modify: `equine-frontend/app/protected/page.tsx`

**Step 1: Replace Supabase queries with Convex**

```tsx
"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";
import { useUser } from "@clerk/nextjs";

export default function ProtectedPage() {
  const { user } = useUser();
  const assessments = useQuery(api.assessments.list);
  const deleteAssessment = useMutation(api.assessments.remove);

  if (!assessments) {
    return <div>Loading...</div>;
  }

  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-4">
        Welcome, {user?.emailAddresses[0]?.emailAddress}
      </h1>

      <h2 className="text-xl mb-4">Your Assessments</h2>

      {assessments.length === 0 ? (
        <p>No assessments yet. Sync from the iOS app to see them here.</p>
      ) : (
        <div className="grid gap-4">
          {assessments.map((assessment) => (
            <div
              key={assessment._id}
              className="border rounded-lg p-4 flex justify-between items-center"
            >
              <div>
                <p className="font-medium">
                  {assessment.vetName} - {assessment.farmName}
                </p>
                <p className="text-sm text-gray-500">
                  {new Date(assessment.visitDate).toLocaleDateString()}
                </p>
              </div>
              <button
                onClick={() => deleteAssessment({ id: assessment._id })}
                className="text-red-500 hover:text-red-700"
              >
                Delete
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
```

**Step 2: Commit**

```bash
git add equine-frontend/app/protected/page.tsx
git commit -m "feat(web): replace Supabase queries with Convex in protected page"
```

---

### Task 21: Remove Supabase Dependencies from Web App

**Files:**
- Delete: `equine-frontend/utils/supabase/` directory
- Delete: `equine-frontend/actions/supabase.ts`
- Modify: `equine-frontend/package.json`

**Step 1: Remove Supabase packages**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npm uninstall @supabase/ssr @supabase/supabase-js
```

**Step 2: Delete Supabase utilities**

```bash
rm -rf equine-frontend/utils/supabase
rm equine-frontend/actions/supabase.ts
```

**Step 3: Update any remaining imports**

Search for and remove any remaining Supabase imports in other files.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(web): remove Supabase dependencies, complete Convex migration"
```

---

## Phase 4: iOS App Migration (Convex Swift SDK)

### Task 22: Add Convex Swift Package

**Files:**
- Modify: Xcode project (via Xcode UI or Package.swift)

**Step 1: Add Convex Swift SDK via Xcode**

1. Open `equine-welfare.xcodeproj` in Xcode
2. File > Add Package Dependencies
3. Enter URL: `https://github.com/get-convex/convex-swift`
4. Add to target: `equine-welfare`

**Step 2: Commit**

```bash
git add equine-welfare.xcodeproj/
git commit -m "feat(ios): add Convex Swift SDK package dependency"
```

---

### Task 23: Create Convex Configuration

**Files:**
- Create: `equine-welfare/Config/ConvexConfig.swift`

**Step 1: Create config file**

```swift
import Foundation

enum ConvexConfig {
    static var deploymentURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "CONVEX_URL") as? String else {
            fatalError("CONVEX_URL not found in Info.plist")
        }
        return url
    }
}
```

**Step 2: Update Secrets.example.xcconfig**

Add:
```
CONVEX_URL = https://your-deployment.convex.cloud
```

**Step 3: Update Info.plist**

Add key: `CONVEX_URL` with value: `$(CONVEX_URL)`

**Step 4: Commit**

```bash
git add equine-welfare/Config/ConvexConfig.swift equine-welfare/Config/Secrets.example.xcconfig
git commit -m "feat(ios): add Convex configuration"
```

---

### Task 24: Create ConvexService

**Files:**
- Create: `equine-welfare/Services/ConvexService.swift`

**Step 1: Create service**

```swift
import Foundation
import Convex

@Observable
class ConvexService {
    static let shared = ConvexService()

    private let client: ConvexClient

    private init() {
        self.client = ConvexClient(deploymentUrl: ConvexConfig.deploymentURL)
    }

    // MARK: - Sync Assessment

    func syncAssessment(_ assessment: Assessment) async throws {
        // Prepare assessment data
        let assessmentData: [String: Any] = [
            "externalId": assessment.id.uuidString,
            "vetName": assessment.vetName,
            "farmName": assessment.farmName,
            "visitDate": assessment.visitDate.timeIntervalSince1970 * 1000,
            "isComplete": assessment.isComplete,
            "sideNotes": assessment.sideNotes as Any
        ]

        // Prepare horses
        let horsesData = assessment.horses.map { horse -> [String: Any] in
            [
                "externalId": horse.uuid.uuidString,
                "name": horse.name,
                "age": horse.age,
                "color": horse.color,
                "sex": horse.sex,
                "breed": horse.breed,
                "otherBreed": horse.otherBreed as Any,
                "timeOnFarm": horse.timeOnFarm,
                "bcsScore": horse.bcsScore,
                "notes": horse.notes as Any,
                "ageUnit": horse.ageUnit.rawValue,
                "timeUnit": horse.timeUnit.rawValue,
                "isHorse": horse.isHorse
            ]
        }

        // Prepare sections
        let sectionsData = assessment.sections.filter { $0.isApplicable }.map { section -> [String: Any] in
            [
                "sectionNumber": section.id,
                "title": section.title,
                "isApplicable": section.isApplicable,
                "infoIconClicks": section.infoIconClicks,
                "subsections": section.subsections.map { subsection -> [String: Any] in
                    [
                        "name": subsection.name,
                        "requirements": subsection.requirements.map { req -> [String: Any] in
                            [
                                "text": req.text,
                                "complianceStatus": req.complianceStatus?.rawValue as Any,
                                "nonComplianceReason": req.nonComplianceReason as Any
                            ]
                        }
                    ]
                }
            ]
        }

        // Call mutation
        try await client.mutation("assessments:syncAssessment", with: [
            "assessment": assessmentData,
            "horses": horsesData,
            "sections": sectionsData
        ])
    }

    // MARK: - Upload Media

    func uploadMedia(data: Data, mediaType: String) async throws -> String {
        // Get upload URL
        let uploadUrl: String = try await client.mutation("files:generateUploadUrl", with: [:])

        // Upload file
        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "POST"
        request.setValue(mediaType == "image" ? "image/jpeg" : "video/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ConvexError.uploadFailed
        }

        // Get storage ID from response header
        guard let storageId = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Storage-Id") else {
            throw ConvexError.uploadFailed
        }

        return storageId
    }
}

enum ConvexError: Error {
    case uploadFailed
    case syncFailed
}
```

**Step 2: Commit**

```bash
git add equine-welfare/Services/ConvexService.swift
git commit -m "feat(ios): create ConvexService for syncing assessments"
```

---

### Task 25: Update PreviousAssessmentRow to Use Convex

**Files:**
- Modify: `equine-welfare/PreviousAssessmentRow.swift`

**Step 1: Replace Supabase upload with Convex sync**

Replace `uploadRTFToSupabase()` method with:

```swift
private func syncToConvex() async {
    isUploading = true
    uploadProgress = 0.1

    do {
        // Sync assessment data
        uploadProgress = 0.3
        try await ConvexService.shared.syncAssessment(assessment)

        // Upload horse media
        uploadProgress = 0.5
        for (index, horse) in assessment.horses.enumerated() {
            if let photoData = horse.photoData {
                try await ConvexService.shared.uploadMedia(
                    data: photoData.data,
                    mediaType: photoData.mediaType.rawValue
                )
            }
            uploadProgress = 0.5 + (Double(index + 1) / Double(assessment.horses.count)) * 0.4
        }

        uploadProgress = 1.0
        uploadSuccessMessage = "Assessment synced successfully!"
        showUploadSuccess = true

    } catch {
        uploadError = error.localizedDescription
        showUploadAlert = true
    }

    isUploading = false
    uploadProgress = 0.0
}
```

**Step 2: Update button to call new method**

Replace `SupabaseService` references with `ConvexService`.

**Step 3: Commit**

```bash
git add equine-welfare/PreviousAssessmentRow.swift
git commit -m "feat(ios): update upload button to use Convex sync"
```

---

### Task 26: Remove Supabase from iOS App

**Files:**
- Delete: `equine-welfare/Utils/SupabaseService.swift`
- Modify: Xcode project to remove Supabase package

**Step 1: Delete SupabaseService**

```bash
rm equine-welfare/Utils/SupabaseService.swift
```

**Step 2: Remove Supabase package via Xcode**

1. Open project in Xcode
2. Select project in navigator
3. Select package dependencies tab
4. Remove Supabase package

**Step 3: Clean up any remaining Supabase references**

Search project for "Supabase" and remove any remaining imports or references.

**Step 4: Build and verify**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(ios): remove Supabase, complete Convex migration"
```

---

### Task 27: Final Verification

**Step 1: Build iOS app**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare && xcodebuild -scheme equine-welfare -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

**Step 2: Build web app**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npm run build
```

**Step 3: Test Convex deployment**

```bash
cd /Users/ajeetgill/Documents/GitHub/ai-coding/equine-welfare/equine-frontend && npx convex dev --once
```

**Step 4: Commit milestone**

```bash
git commit --allow-empty -m "milestone: Cleanup and Clerk + Convex migration complete"
```

---

## Environment Variables Checklist

After completing the migration, ensure these are set:

**Web App (.env.local):**
```
NEXT_PUBLIC_CONVEX_URL=https://your-deployment.convex.cloud
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
CLERK_JWT_ISSUER_DOMAIN=https://your-clerk-app.clerk.accounts.dev
```

**iOS App (Secrets.xcconfig):**
```
CONVEX_URL=https://your-deployment.convex.cloud
```

---

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| 1 | 1-9 | Code cleanup (security fix, dead code, debug statements) |
| 2 | 10-14 | Convex backend setup (schema, mutations, Clerk config) |
| 3 | 15-21 | Web app migration (Clerk auth, Convex queries) |
| 4 | 22-27 | iOS app migration (Convex Swift SDK, sync) |
