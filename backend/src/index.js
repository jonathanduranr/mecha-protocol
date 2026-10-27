export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Content-Type": "application/json"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      // 1. OBTENER TOP 10 MUNDIAL (Mejor récord por cada piloto)
      if (request.method === "GET" && (url.pathname === "/api/leaderboard" || url.pathname === "/leaderboard" || url.pathname === "/")) {
        const query = `
          SELECT pilot_id, survival_time, level, created_at 
          FROM leaderboard 
          ORDER BY survival_time DESC 
          LIMIT 10
        `;
        const { results } = await env.DB.prepare(query).all();
        return new Response(JSON.stringify({ 
          success: true, 
          leaderboard: results || [] 
        }), {
          headers: corsHeaders
        });
      }

      // 2. REGISTRAR O ACTUALIZAR PUNTUACIÓN DE PILOTO (UPSERT)
      if (request.method === "POST" && (url.pathname === "/api/score" || url.pathname === "/score")) {
        let body;
        try {
          body = await request.json();
        } catch (e) {
          return new Response(JSON.stringify({ success: false, error: "Invalid JSON body" }), {
            status: 400,
            headers: corsHeaders
          });
        }

        let pilot_id = String(body.pilot_id || "PILOTO-DESCONOCIDO").trim();
        pilot_id = pilot_id.replace(/[^a-zA-Z0-9_\-]/g, "").substring(0, 16);
        if (!pilot_id) pilot_id = "PILOTO-MK1";

        let old_pilot_id = body.old_pilot_id ? String(body.old_pilot_id).trim() : null;

        const survival_time = parseFloat(body.survival_time) || 0.0;
        const level = parseInt(body.level, 10) || 1;

        if (survival_time <= 0 || survival_time > 86400) {
          return new Response(JSON.stringify({ success: false, error: "Invalid survival time" }), {
            status: 400,
            headers: corsHeaders
          });
        }

        // Si cambió de apodo en la misma sesión, limpiar el nombre anterior
        if (old_pilot_id && old_pilot_id !== pilot_id) {
          await env.DB.prepare("DELETE FROM leaderboard WHERE pilot_id = ?").bind(old_pilot_id).run();
        }

        // UPSERT: 1 entrada única por piloto con su récord máximo
        await env.DB.prepare(`
          INSERT INTO leaderboard (pilot_id, survival_time, level, created_at)
          VALUES (?, ?, ?, CURRENT_TIMESTAMP)
          ON CONFLICT(pilot_id) DO UPDATE SET
            survival_time = CASE 
              WHEN excluded.survival_time > leaderboard.survival_time THEN excluded.survival_time 
              ELSE leaderboard.survival_time 
            END,
            level = CASE 
              WHEN excluded.survival_time > leaderboard.survival_time THEN excluded.level 
              ELSE leaderboard.level 
            END,
            created_at = CASE 
              WHEN excluded.survival_time > leaderboard.survival_time THEN CURRENT_TIMESTAMP 
              ELSE leaderboard.created_at 
            END
        `).bind(pilot_id, survival_time, level).run();

        // Calcular posición actual del piloto en el ranking mundial
        const rankResult = await env.DB.prepare(
          "SELECT COUNT(*) as better_count FROM leaderboard WHERE survival_time > (SELECT survival_time FROM leaderboard WHERE pilot_id = ?)"
        ).bind(pilot_id).first();
        const rank = (rankResult?.better_count || 0) + 1;

        // Traer Top 10 actualizado
        const { results: top10 } = await env.DB.prepare(
          "SELECT pilot_id, survival_time, level, created_at FROM leaderboard ORDER BY survival_time DESC LIMIT 10"
        ).all();

        return new Response(JSON.stringify({ 
          success: true, 
          rank: rank,
          pilot_id: pilot_id,
          top10: top10 || [] 
        }), {
          headers: corsHeaders
        });
      }

      return new Response(JSON.stringify({ error: "Endpoint not found" }), {
        status: 404,
        headers: corsHeaders
      });
    } catch (err) {
      return new Response(JSON.stringify({ success: false, error: err.message }), {
        status: 500,
        headers: corsHeaders
      });
    }
  }
};
