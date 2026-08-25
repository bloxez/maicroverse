# AI Task Setup Scripts

This folder contains optional mAIql task setup scripts.

Users choose if and when to import and run these scripts in their own project. Nothing here is auto-seeded by instance creation.

## Files

- `default_tasks.gql`: Resets and recreates the default AI task set used in this workspace.

## How To Run

You can run `default_tasks.gql` from either path:

1. IDE: open `scripts/.../default_tasks.gql` and click Run script.
2. CLI: run it with `script run` / `gql run` using a local file path or uploaded script path.

## Tasks Created By `default_tasks.gql`

1. `describe_image`
- Purpose: Generate a rich visual description from an image.
- Use case: Accessibility text, quick media triage, and human review summaries.

2. `embed_text`
- Purpose: Convert text into vector embeddings.
- Use case: Semantic search, similarity matching, and retrieval pipelines.

3. `json_extraction`
- Purpose: Extract structured JSON directly from an image.
- Use case: One-step image-to-schema extraction when OCR staging is not required.

4. `ocr_markdown`
- Purpose: Convert image/PDF content into clean Markdown text.
- Use case: OCR-first workflows before classification or JSON extraction.

5. `text_json`
- Purpose: Extract structured JSON from text or OCR output.
- Use case: Schema mapping after OCR or transcript generation.

6. `transcribe_audio`
- Purpose: Transcribe spoken audio to plain text.
- Use case: Preprocessing step before summarization, classification, or `text_json`.

## Notes

- The script is idempotent in practice: it deletes target keys first, then recreates them.
- If you customize prompts or labels, keep your edited script in project version control and rerun as needed.
