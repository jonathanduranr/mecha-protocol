const SECRET_SALT = "mp_cyber_core_sig_99x8172b";

async function computeSha256(message) {
  const msgBuffer = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
}

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "*",
      "Access-Control-Max-Age": "86400",
      "Cross-Origin-Resource-Policy": "cross-origin",
      "Content-Type": "application/json"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      // 1. OBTENER TOP 10 MUNDIAL (Público con soporte para resaltar al usuario)
      if (request.method === "GET" && (url.pathname === "/api/leaderboard" || url.pathname === "/leaderboard" || url.pathname === "/")) {
        const userId = url.searchParams.get("user_id") || "";
        const query = `
          SELECT user_id, pilot_name, survival_time, level, created_at 
          FROM leaderboard 
          ORDER BY survival_time DESC 
          LIMIT 10
        `;
        const { results } = await env.DB.prepare(query).all();
        const sanitized = (results || []).map(row => ({
          pilot_name: row.pilot_name,
          survival_time: row.survival_time,
          level: row.level,
          is_me: Boolean(userId && row.user_id === userId)
        }));

        let user_record = null;
        if (userId) {
          const userRow = await env.DB.prepare(`
            SELECT pilot_name, survival_time, level 
            FROM leaderboard 
            WHERE user_id = ?
          `).bind(userId).first();
          if (userRow) {
            const rankRes = await env.DB.prepare(`
              SELECT COUNT(*) as better_count 
              FROM leaderboard 
              WHERE survival_time > ?
            `).bind(userRow.survival_time).first();
            user_record = {
              pilot_name: userRow.pilot_name,
              survival_time: userRow.survival_time,
              level: userRow.level,
              rank: (rankRes?.better_count || 0) + 1
            };
          }
        }

        return new Response(JSON.stringify({ 
          success: true, 
          leaderboard: sanitized,
          user_record: user_record
        }), {
          headers: corsHeaders
        });
      }

      // 2. REGISTRAR O ACTUALIZAR PUNTUACIÓN DE PILOTO CON FIRMA CRIPTOGRÁFICA
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

        // Validación de identidad (UUID)
        let user_id = String(body.user_id || "").trim();
        if (!user_id || user_id.length < 10 || user_id.length > 64) {
          return new Response(JSON.stringify({ success: false, error: "Invalid user_id" }), {
            status: 400,
            headers: corsHeaders
          });
        }

        let pilot_name = String(body.pilot_name || "PILOTO-MK1").trim();
        pilot_name = pilot_name.replace(/[^a-zA-Z0-9_\-]/g, "").substring(0, 16);
        if (!pilot_name) pilot_name = "PILOTO-MK1";

        const survival_time = parseFloat(body.survival_time) || 0.0;
        const level = parseInt(body.level, 10) || 1;

        if (level <= 0) {
          return new Response(JSON.stringify({ success: false, error: "Registro denegado: Violación de integridad del cliente." }), {
            status: 403,
            headers: corsHeaders
          });
        }

        if (survival_time <= 0 || survival_time > 86400) {
          return new Response(JSON.stringify({ success: false, error: "Invalid survival time" }), {
            status: 400,
            headers: corsHeaders
          });
        }

        // --- VERIFICACIÓN DE FIRMA CRIPTOGRÁFICA (ANTI-HACK) ---
        const clientToken = String(body.token || "").trim().toLowerCase();
        const timeStr = survival_time.toFixed(1);
        const expectedRaw = `${user_id}:${timeStr}:${level}:${SECRET_SALT}`;
        const expectedToken = await computeSha256(expectedRaw);

        if (!clientToken || clientToken !== expectedToken) {
          return new Response(JSON.stringify({ 
            success: false, 
            error: "Firma criptográfica inválida (Petición no autorizada)" 
          }), {
            status: 403,
            headers: corsHeaders
          });
        }

        // UPSERT SEGURO: Actualiza sólo al usuario propietario del user_id
        await env.DB.prepare(`
          INSERT INTO leaderboard (user_id, pilot_name, survival_time, level, updated_at)
          VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
          ON CONFLICT(user_id) DO UPDATE SET
            pilot_name = excluded.pilot_name,
            survival_time = CASE 
              WHEN excluded.survival_time > leaderboard.survival_time THEN excluded.survival_time 
              ELSE leaderboard.survival_time 
            END,
            level = CASE 
              WHEN excluded.survival_time > leaderboard.survival_time THEN excluded.level 
              ELSE leaderboard.level 
            END,
            updated_at = CURRENT_TIMESTAMP
        `).bind(user_id, pilot_name, survival_time, level).run();

        // Calcular posición en el ranking mundial
        const rankResult = await env.DB.prepare(`
          SELECT COUNT(*) as better_count 
          FROM leaderboard 
          WHERE survival_time > (SELECT survival_time FROM leaderboard WHERE user_id = ?)
        `).bind(user_id).first();
        const rank = (rankResult?.better_count || 0) + 1;

        // Traer Top 10 actualizado
        const { results: top10 } = await env.DB.prepare(`
          SELECT user_id, pilot_name, survival_time, level, created_at 
          FROM leaderboard 
          ORDER BY survival_time DESC 
          LIMIT 10
        `).all();

        const sanitizedTop10 = (top10 || []).map(row => ({
          pilot_name: row.pilot_name,
          survival_time: row.survival_time,
          level: row.level,
          is_me: row.user_id === user_id
        }));

        return new Response(JSON.stringify({ 
          success: true, 
          rank: rank,
          pilot_name: pilot_name,
          top10: sanitizedTop10
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
