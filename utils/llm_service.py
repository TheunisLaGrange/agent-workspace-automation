import sys
import time
import json
from pathlib import Path
from dotenv import load_dotenv
import google.genai as genai
from google.genai import types
from google.genai.errors import ServerError
from pydantic import BaseModel, Field

load_dotenv()

class RepoMetadataOutput(BaseModel):
    description: str = Field(
        description="A crisp, technical GitHub repository description strictly under 350 characters."
    )
    suggested_topics: list[str] = Field(
        description="Up to 6 lowercase, hyphenated GitHub topic tags relevant to the codebase."
    )

def send_with_retry(client: genai.Client, model: str, prompt: str, schema: type[BaseModel], max_retries: int = 5, initial_delay: int = 2):
    delay = initial_delay
    for attempt in range(max_retries):
        try:
            return client.models.generate_content(
                model=model,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=schema,
                    temperature=0.2,
                )
            )
        except ServerError as e:
            if e.code == 503 and attempt < max_retries - 1:
                print(f"[WARN] Gemini busy (503). Retrying in {delay}s ({attempt + 1}/{max_retries})...", file=sys.stderr)
                time.sleep(delay)
                delay *= 2
            else:
                raise e

def process_readme_to_metadata(input_path: Path, output_path: Path) -> None:
    if not input_path.exists():
        raise FileNotFoundError(f"Input contract file not found: {input_path}")

    with open(input_path, "r", encoding="utf-8") as f:
        payload = json.load(f)

    context = payload.get("context", {})
    constraints = payload.get("constraints", {})
    
    repo_name = context.get("repo_name", "unknown-repo")
    language = context.get("primary_language", "Unknown")
    readme_text = context.get("readme_content", "")
    max_chars = int(constraints.get("max_characters", 350))

    if not readme_text.strip():
        result = {
            "status": "skipped",
            "repo_name": repo_name,
            "reason": "Empty README content provided."
        }
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=4)
        return

    prompt = f"""
You are a senior software architect writing GitHub repository metadata.
Read the README content below and generate a single-paragraph repository description.

Strict Rules:
1. The description MUST be strictly {max_chars} characters or fewer.
2. Focus on architecture, core technologies, and practical problem solved.
3. Do not use marketing fluff, emojis, or markdown formatting.

Repository Name: {repo_name}
Primary Language: {language}

README Content:
{readme_text[:12000]}
"""

    client = genai.Client()
    response = send_with_retry(
        client=client,
        model="gemini-3.6-flash",
        prompt=prompt,
        schema=RepoMetadataOutput
    )

    if not response or not getattr(response, "text", None):
        raise ValueError("Gemini API returned an empty response.")

    parsed = json.loads(response.text)
    clean_desc = parsed["description"].strip()

    # Enforce hard character ceiling safely
    if len(clean_desc) > max_chars:
        clean_desc = clean_desc[:max_chars - 3].rsplit(" ", 1)[0] + "..."

    output_envelope = {
        "status": "success",
        "repo_name": repo_name,
        "description": clean_desc,
        "character_count": len(clean_desc),
        "suggested_topics": [t.lower().strip() for t in parsed.get("suggested_topics", [])][:6]
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output_envelope, f, indent=4)

    print(f"[OK] Generated {len(clean_desc)}-char description for '{repo_name}' -> {output_path}")

if __name__ == "__main__":
    in_file = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("llm_input.json")
    out_file = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("llm_output.json")
    process_readme_to_metadata(in_file, out_file)
