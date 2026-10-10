import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'};
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers:cors});
  if (request.method !== 'POST') return new Response('Method not allowed',{status:405,headers:cors});
  const url=Deno.env.get('SUPABASE_URL')!, key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const server=createClient(url,key,{auth:{persistSession:false}});
  const token=request.headers.get('Authorization')?.replace(/^Bearer /i,'');
  if(!token) return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  const {data,error}=await server.auth.getUser(token);
  if(error||!data.user) return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  // Identity is obtained from the verified bearer token, never request body.
  const {error:deletion}=await server.auth.admin.deleteUser(data.user.id);
  return Response.json(deletion?{error:deletion.message}:{deleted:true},{status:deletion?400:200,headers:cors});
});
