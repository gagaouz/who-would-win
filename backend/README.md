# Who Would Win? — Backend

This is the Node.js/TypeScript backend API that powers the **Who Would Win?** iOS app. It exposes a single `/api/battle` endpoint that accepts two animal IDs, calls the Claude AI model, and returns an exciting (kid-friendly!) battle result with a winner, narration, fun fact, and health percentages.

---

## Prerequisites

- **Node.js 20+** — [Download here](https://nodejs.org)
- **An Anthropic API key** — see below

### Getting an Anthropic API Key

1. Go to [console.anthropic.com](https://console.anthropic.com) and sign up (or log in).
2. Navigate to **API Keys** in the left sidebar.
3. Click **Create Key**, give it a name, and copy the key — you won't be able to see it again.

---

## Install Dependencies

```bash
npm install
```

---

## Environment Setup

Copy the example environment file and add your API key:

```bash
cp .env.example .env
```

Open `.env` and replace `your_key_here` with your actual Anthropic API key:

```
ANTHROPIC_API_KEY=sk-ant-...
PORT=3000
```

---

## Run Locally (Development)

```bash
npm run dev
```

The server will start on `http://localhost:3000`. You should see:

```
Who Would Win backend running on port 3000
```

You can verify it's working by visiting `http://localhost:3000/health` — it should return `{"status":"ok"}`.

---

## Build for Production

```bash
npm run build
npm start
```

`npm run build` compiles TypeScript to JavaScript in the `dist/` folder. `npm start` runs the compiled output.

---

## Deploy to Railway (Free & Easy)

[Railway](https://railway.app) is the simplest way to get this backend live in minutes.

### Step-by-step:

1. **Go to [railway.app](https://railway.app)** and sign up for a free account (GitHub login works great).

2. **Create a new project:**
   - Click **"New Project"**
   - Choose **"Deploy from GitHub repo"** and connect your GitHub account, then select your repository.
   - Alternatively, choose **"Empty project"** and use the Railway CLI to push from your local machine.

3. **Add your environment variable:**
   - Inside your project, click on the service, then go to the **"Variables"** tab.
   - Click **"New Variable"** and add:
     - Key: `ANTHROPIC_API_KEY`
     - Value: your actual API key

4. **Railway auto-detects Node.js** and will automatically run `npm run build` and `npm start`. No extra configuration needed.

5. **Get your URL:**
   - Go to the **"Settings"** tab of your service.
   - Under **"Networking"**, click **"Generate Domain"**.
   - You'll get a URL like `https://your-app-name.railway.app`. Copy it.

---

## Connect the iOS App

Once your backend is deployed, open the iOS project and update the base URL:

```
ios/WhoWouldWin/App/AppConfig.swift
```

Replace `"https://your-backend-url.com"` with your Railway URL, for example:

```swift
static let baseURL = "https://your-app-name.railway.app"
```

---

## API Reference

### `GET /health`

Returns `{ "status": "ok" }`. Use this to check that the server is running.

### `POST /api/battle`

Request body:

```json
{
  "fighter1": "lion",
  "fighter2": "grizzly_bear"
}
```

Both `fighter1` and `fighter2` must be valid animal IDs from the supported list of 50 animals.

Successful response:

```json
{
  "winner": "lion",
  "narration": "The lion roars with the power of a thousand thunderstorms, sending the grizzly stumbling back! With one mighty swipe of its giant paw, the grizzly rebounds — but the lion is just too fast!",
  "funFact": "Lions can run at speeds up to 50 mph in short bursts and have a bite force of around 650 PSI!",
  "winnerHealthPercent": 72,
  "loserHealthPercent": 14
}
```

**Rate limiting:** Each IP address is limited to **30 requests per hour**. Exceeding this limit returns a `429` status.
