# Supabase Contract

This document describes the current client-side backend contract. The app keeps the existing Supabase table and bucket unchanged for the pilot.

## Required Resources

- Storage bucket: `gif_storage`
- Metadata table: `user_meta`

## Current Metadata Payload

The app writes one metadata row per drawing attempt using the existing `user_meta` shape:

```text
fullName
age
sex
filename
timeToComplete
repeatTaps
complaint
comment
```

No new Supabase columns are required in this pass.

## Filename Format

GIF object names use:

```text
{userName}_{taskType}_{sessionId}_{attemptId}.gif
```

Where:

- `userName` is the participant full name from the home-page form, transliterated and sanitized for filenames.
- `taskType` is `clock` or `cube`.
- `sessionId` is generated when a new participant session starts.
- `attemptId` is generated once for a drawing attempt.

Example:

```text
Ivan_Ivanov_clock_s_mih96z_01abc_a_mih970_09xyz.gif
```

The original participant name remains in the `fullName` metadata field.

## Retry Behavior

Retries are idempotent at the client level:

- A failed attempt keeps the same filename and attempt metadata.
- Manual upload reads the pending attempt sidecar JSON before uploading.
- Storage upload uses object upsert, so retrying the same attempt targets the same object name.
- Metadata still uses the existing `filename` field as the durable attempt reference.

## Pending Upload Sidecar

When upload fails, the app saves:

```text
{userName}_{taskType}_{sessionId}_{attemptId}.gif
{userName}_{taskType}_{sessionId}_{attemptId}.json
```

The JSON sidecar stores:

```text
fullName
age
sex
complaint
taskType
sessionId
attemptId
fileName
timeToComplete
repeatTaps
createdAt
```

Manual upload uses this sidecar so a pending GIF remains associated with the original participant even after a new session starts.

Legacy pending GIFs without sidecars are still supported as best-effort uploads. They use the currently confirmed participant metadata and should be reviewed by the operator before upload.

## Future Schema Recommendation

When schema changes are allowed, add explicit columns for:

```text
sessionId
attemptId
taskType
createdAt
uploadedAt
appVersion
```

At that point, `filename` can remain the storage object reference instead of carrying all attempt identity.
