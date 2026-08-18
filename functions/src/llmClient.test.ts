// functions/src/llmClient.test.ts
import { generateText } from './llmClient';

const originalFetch = global.fetch;

describe('generateText', () => {
  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('returns Groq\'s response when Groq succeeds', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ choices: [{ message: { content: 'groq response' } }] }),
    }) as unknown as typeof fetch;

    const result = await generateText('a prompt');

    expect(result).toBe('groq response');
    expect(global.fetch).toHaveBeenCalledTimes(1);
    expect((global.fetch as jest.Mock).mock.calls[0][0]).toContain('groq.com');
  });

  it('falls back to NVIDIA NIM when Groq fails', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 429 })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ choices: [{ message: { content: 'nim response' } }] }),
      }) as unknown as typeof fetch;

    const result = await generateText('a prompt');

    expect(result).toBe('nim response');
    expect(global.fetch).toHaveBeenCalledTimes(2);
    expect((global.fetch as jest.Mock).mock.calls[1][0]).toContain('nvidia.com');
  });

  it('throws if both Groq and NVIDIA NIM fail', async () => {
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 500 })
      .mockResolvedValueOnce({ ok: false, status: 500 }) as unknown as typeof fetch;

    await expect(generateText('a prompt')).rejects.toThrow();
  });
});
