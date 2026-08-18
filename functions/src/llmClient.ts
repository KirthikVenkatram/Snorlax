// functions/src/llmClient.ts

// Read at call time (not module load) so emulator/test setups that populate
// the environment after import still see the configured credentials.
function groqApiKey(): string {
  return process.env.GROQ_API_KEY ?? '';
}

function nimApiKey(): string {
  return process.env.NVIDIA_NIM_API_KEY ?? '';
}

interface ChatCompletionResponse {
  choices: Array<{ message: { content: string } }>;
}

async function callGroq(prompt: string): Promise<string> {
  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${groqApiKey()}`,
    },
    body: JSON.stringify({
      model: 'llama-3.3-70b-versatile',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0,
    }),
  });
  if (!response.ok) {
    throw new Error(`Groq request failed: ${response.status}`);
  }
  const data = (await response.json()) as ChatCompletionResponse;
  return data.choices[0].message.content;
}

async function callNvidiaNim(prompt: string): Promise<string> {
  const response = await fetch('https://integrate.api.nvidia.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${nimApiKey()}`,
    },
    body: JSON.stringify({
      model: 'meta/llama-3.1-70b-instruct',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0,
    }),
  });
  if (!response.ok) {
    throw new Error(`NVIDIA NIM request failed: ${response.status}`);
  }
  const data = (await response.json()) as ChatCompletionResponse;
  return data.choices[0].message.content;
}

/**
 * Tries Groq first (fast, generous free tier); falls back to NVIDIA NIM if
 * Groq errors or is rate-limited. Throws only if both fail.
 */
export async function generateText(prompt: string): Promise<string> {
  try {
    return await callGroq(prompt);
  } catch (groqError) {
    console.error('Groq request failed, falling back to NVIDIA NIM', groqError);
    return callNvidiaNim(prompt);
  }
}
