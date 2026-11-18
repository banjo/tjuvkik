import type { APIRoute, GetStaticPaths } from "astro";
import { schema, schemas } from "../../lib/repo";

export const getStaticPaths: GetStaticPaths = () => schemas().map((name) => ({ params: { name } }));

export const GET: APIRoute = ({ params }) =>
  new Response(schema(String(params.name)), {
    headers: { "Content-Type": "application/schema+json; charset=utf-8" },
  });
