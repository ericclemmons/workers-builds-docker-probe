import { DurableObject } from "cloudflare:workers";

export class ProbeContainer extends DurableObject<Env> {
	async fetch(request: Request): Promise<Response> {
		const container = this.ctx.container!;

		if (!container.running) {
			container.start({ image: container.images.base, instance: "lite" });
		}

		const port = container.getTcpPort(8080);

		for (let attempt = 0; attempt < 50; attempt++) {
			try {
				const response = await port.fetch("http://container/health", {
					signal: AbortSignal.timeout(1000),
				});
				await response.body?.cancel();

				if (response.ok) {
					return port.fetch(new Request("http://container/", request));
				}
			} catch {
				// Not listening yet.
			}

			await scheduler.wait(200);
		}

		return new Response("Container did not become ready", { status: 503 });
	}
}

export default {
	fetch(request, env) {
		return env.PROBE_CONTAINER.getByName("probe").fetch(request);
	},
} satisfies ExportedHandler<Env>;
