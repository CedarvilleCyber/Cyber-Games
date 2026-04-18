import { mkdir } from "node:fs/promises";

// Ensure the uploads directory exists
await mkdir("uploads", { recursive: true });

const server = Bun.serve({
  port: 3000,
  async fetch(req) {
    const url = new URL(req.url);

    if (req.method === "POST" && url.pathname === "/upload") {
      try {
        const formData = await req.formData();
        const file = formData.get("file");

        if (!file || typeof file === "string") {
          return new Response("No file uploaded in the 'file' field.\n", { status: 400 });
        }

        const filePath = `uploads/${file.name}`;
        await Bun.write(filePath, file);

        return new Response(`File uploaded successfully to ${filePath}\n`, { status: 200 });
      } catch (error) {
        console.error(error);
        return new Response("Error processing upload\n", { status: 500 });
      }
    }

    return new Response(
      "Upload Server Running.\n\n" +
      "Usage:\n" +
      "  curl -F 'file=@<your-file>' http://localhost:3000/upload\n"
    );
  },
});

console.log(`Listening on http://localhost:${server.port}...`);
