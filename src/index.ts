interface Env {
  DB: D1Database;
  ASSETS: R2Bucket;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/") {
      return new Response("Founder's Vent is running.");
    }

    if (url.pathname === "/api/test-db") {
      try {
        const result = await env.DB
          .prepare("SELECT 1 AS connected")
          .first<{ connected: number }>();

        return Response.json({
          success: true,
          database: result?.connected === 1
        });
      } catch (error) {
        return Response.json(
          {
            success: false,
            error: error instanceof Error ? error.message : "Database connection failed"
          },
          { status: 500 }
        );
      }
    }

    if (url.pathname === "/api/test-r2") {
      try {
        const testKey = "_system/connection-test.txt";

        await env.ASSETS.put(
          testKey,
          "Founder's Vent R2 connection successful."
        );

        const object = await env.ASSETS.get(testKey);

        if (!object) {
          throw new Error("R2 object could not be retrieved.");
        }

        const text = await object.text();

        return Response.json({
          success: true,
          storage: text === "Founder's Vent R2 connection successful."
        });
      } catch (error) {
        return Response.json(
          {
            success: false,
            error: error instanceof Error ? error.message : "R2 connection failed"
          },
          { status: 500 }
        );
      }
    }

    return new Response("Not Found", { status: 404 });
  }
};
