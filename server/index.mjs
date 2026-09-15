import 'dotenv/config';
import cors from 'cors';
import express from 'express';

const app = express();
const port = process.env.PORT || 8080;
const host = process.env.HOST || '0.0.0.0';

app.use(cors());
app.use(express.json({ limit: '8mb' }));

app.get('/health', (_request, response) => {
  response.json({ ok: true, service: 'recipe-generation' });
});

app.post('/recognize', async (request, response) => {
  const image = request.body?.image;
  const mimeType = request.body?.mimeType;
  if (typeof image !== 'string' || image.length === 0 || image.length > 7_000_000) {
    return response.status(400).json({ error: 'A valid image is required.' });
  }
  if (typeof mimeType !== 'string' || !mimeType.startsWith('image/')) {
    return response.status(400).json({ error: 'A valid image MIME type is required.' });
  }

  try {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey || apiKey.startsWith('replace-')) {
      return response.status(503).json({ error: 'GEMINI_API_KEY is not configured.' });
    }

    const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              {
                inlineData: { mimeType, data: image },
              },
              {
                text: 'Identify the edible ingredients visible in this image. Return common ingredient names only. Ignore plates, packaging, utensils, people, and non-food objects. Do not guess ingredients that are not visibly supported.',
              },
            ],
          }],
          systemInstruction: {
            parts: [{
              text: 'Return only JSON matching the requested schema. Use short singular or standard grocery names, with no quantities or commentary.',
            }],
          },
          generationConfig: {
            temperature: 0.1,
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: {
                ingredients: { type: 'ARRAY', items: { type: 'STRING' } },
              },
              required: ['ingredients'],
            },
          },
        }),
      },
    );

    if (!geminiResponse.ok) {
      throw new Error(`Gemini returned ${geminiResponse.status}: ${(await geminiResponse.text()).slice(0, 500)}`);
    }
    const result = await geminiResponse.json();
    const content = result.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!content) throw new Error('The model returned no ingredients.');
    const parsed = JSON.parse(content);
    const ingredients = Array.isArray(parsed.ingredients)
      ? parsed.ingredients
          .filter((item) => typeof item === 'string')
          .map((item) => item.trim().slice(0, 80))
          .filter(Boolean)
          .slice(0, 20)
      : [];
    return response.json({ ingredients });
  } catch (error) {
    console.error('Ingredient recognition failed:', error.message);
    return response.status(502).json({ error: 'Ingredient recognition failed.' });
  }
});

app.post('/recipes', async (request, response) => {
  const ingredients = request.body?.ingredients;
  const preferences = request.body?.preferences ?? {};
  if (!Array.isArray(ingredients) || ingredients.length === 0 || ingredients.length > 30) {
    return response.status(400).json({ error: 'ingredients must be a non-empty array.' });
  }

  const cleanIngredients = ingredients
    .filter((item) => typeof item === 'string')
    .map((item) => item.trim().slice(0, 80))
    .filter(Boolean);
  if (cleanIngredients.length === 0) {
    return response.status(400).json({ error: 'No valid ingredients were provided.' });
  }

  try {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey || apiKey.startsWith('replace-')) {
      return response.status(503).json({ error: 'GEMINI_API_KEY is not configured.' });
    }

    const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: `Create a practical leftover recipe using only these available ingredients: ${cleanIngredients.join(', ')}. Preferences: diet=${String(preferences.diet || 'any')}, servings=${Number(preferences.servings) || 2}, maximum time=${Number(preferences.maxMinutes) || 30} minutes, language=${String(preferences.language || 'English')}. Write every user-facing recipe field in the requested language. Also provide a short English tutorialSearchQuery suitable for a YouTube search; it must describe this exact dish, not claim to be a verified external URL.`,
            }],
          }],
          systemInstruction: {
            parts: [{
              text: 'Be concise. Do not invent unavailable main ingredients. Return only JSON matching the requested schema.',
            }],
          },
          generationConfig: {
            temperature: 0.8,
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: {
                title: { type: 'STRING' },
                subtitle: { type: 'STRING' },
                time: { type: 'STRING' },
                steps: { type: 'ARRAY', items: { type: 'STRING' } },
                tutorialSearchQuery: { type: 'STRING' },
              },
              required: ['title', 'subtitle', 'time', 'steps', 'tutorialSearchQuery'],
            },
          },
        }),
      },
    );

    if (!geminiResponse.ok) {
      throw new Error(`Gemini returned ${geminiResponse.status}: ${(await geminiResponse.text()).slice(0, 500)}`);
    }
    const result = await geminiResponse.json();
    const content = result.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!content) throw new Error('The model returned no recipe.');
    return response.json(JSON.parse(content));
  } catch (error) {
    console.error('Recipe generation failed:', error.message);
    return response.status(502).json({ error: 'Recipe generation failed.' });
  }
});

app.listen(port, host, () => {
  console.log(`Recipe API listening at http://${host}:${port}`);
  if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY.startsWith('replace-')) {
    console.warn('GEMINI_API_KEY is not configured. Health checks work, AI requests will fail.');
  }
});