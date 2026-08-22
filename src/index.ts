interface Env {
  DB: D1Database;
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

    return new Response("Not Found", { status: 404 });
  }
};
