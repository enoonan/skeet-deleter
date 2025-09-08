defmodule SkeetDeleterWeb.AtProtoOauthController do
  use SkeetDeleterWeb, :controller
  alias SkeetDeleter.Accounts

  def client_metadata(conn, _) do
    conn
    |> put_resp_header("cache-control", "no-cache")
    |> json(%{
      "client_id" => client_id(),
      "application_type" => "web",
      "grant_types" => [
        "authorization_code",
        "refresh_token"
      ],
      "scope" => "atproto atproto+transition:generic transition:generic",
      "response_types" => ["code"],
      "redirect_uris" => [redirect_uri()],
      "dpop_bound_access_tokens" => true,
      "token_endpoint_auth_method" => "private_key_jwt",
      "token_endpoint_auth_signing_alg" => "ES256",
      "jwks_uri" => ~p"/bsky/oauth/jwks.json" |> url,
      "client_name" => "Skeet Deleter",
      "client_uri" => ~p"/" |> url
    })
  end

  def jwks(conn, _params) do
    {_, jwk} = Application.fetch_env!(:skeet_deleter, :jwk_key)

    key =
      jwk
      |> Map.delete("d")
      |> Map.put("kid", "key-1")
      |> Map.put("use", "sig")
      |> Map.put("alg", "ES256")

    conn |> json(%{"keys" => [key]})
  end

  def do_sign_in_register(conn, params) do
    handle = Map.get(params, "handle")

    did_resolver_url =
      "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=#{handle}"

    did_document_url = "https://plc.directory"
    well_known_path = ".well-known/oauth-protected-resource"

    with {:ok, %{status: 200, body: %{"did" => did}}} <- Req.get(did_resolver_url),
         {:ok, %{status: 200, body: document}} <- Req.get("#{did_document_url}/#{did}"),
         {:ok, document} <- Jason.decode(document),
         %{"service" => [%{"serviceEndpoint" => service_endpoint} | _rest]} = document,
         {:ok, %{status: 200, body: service_meta}} <-
           Req.get("#{service_endpoint}/#{well_known_path}"),
         %{"authorization_servers" => [auth_server | _rest]} <- service_meta,
         {:ok, %{status: 200, body: oauth_server_data}} <-
           Req.get("#{auth_server}/.well-known/oauth-authorization-server"),
         state <- :crypto.strong_rand_bytes(28) |> Base.url_encode64() |> String.slice(0, 28),
         code_verifier <-
           :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> String.replace("=", ""),
         code_challenge <-
           :crypto.hash(:sha256, code_verifier) |> Base.url_encode64() |> String.replace("=", ""),
         %{
           "pushed_authorization_request_endpoint" => par_endpoint,
           "authorization_endpoint" => authorization_endpoint,
           "token_endpoint" => token_endpoint
         } <- oauth_server_data,
         client_assertion <- create_client_assertion(auth_server),
         {:ok, %{status: 201, body: par_res_body, headers: headers}} <-
           Req.post(par_endpoint,
             headers: [{"content-type", "application/x-www-form-urlencoded"}],
             form: [
               grant_type: "authorization_code",
               response_type: "code",
               client_id: client_id(),
               scope: "atproto atproto+transition:generic transition:generic",
               state: state,
               code_challenge: code_challenge,
               code_challenge_method: "S256",
               client_assertion: client_assertion,
               client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
               redirect_uri: redirect_uri(),
               login_hint: handle
             ]
           ) do
      %{"dpop-nonce" => [dpop_nonce | _rest]} = headers
      %{"request_uri" => request_uri} = par_res_body
      auth_q_params = URI.encode_query(%{"client_id" => client_id(), request_uri: request_uri})
      authorization_url = "#{authorization_endpoint}?" <> auth_q_params

      # Redirect the user
      conn
      |> put_session(:oauth_state,
        state: state,
        did: did,
        handle: handle,
        code_verifier: code_verifier,
        token_endpoint: token_endpoint,
        dpop_nonce: dpop_nonce
      )
      |> dbg
      |> redirect(external: authorization_url)
    end
  end

  def sign_in_register(conn, _params) do
    case conn |> get_session(:current_user) do
      nil ->
        form = Phoenix.Component.to_form(%{"handle" => ""})

        conn
        |> assign(:form, form)
        |> render(:sign_in_register)

      _ ->
        conn |> redirect(to: ~p"/dashboard")
    end
  end

  def oauth_callback(conn, %{"state" => state, "iss" => issuer, "code" => code}) do
    # %{"state" => state, "iss" => issuer, "code" => code} = params
    oauth_state = conn |> get_session(:oauth_state, [])
    dbg({oauth_state, state})

    case oauth_state |> Keyword.get(:state) == state do
      false ->
        conn |> put_status(404) |> json(:not_found)

      true ->
        case exchange_code_for_tokens(code, issuer, oauth_state) do
          {:error, _} ->
            conn |> put_status(404) |> json(:not_found)

          {:ok, params} ->
            %{
              "sub" => did,
              "access_token" => access_token,
              "refresh_token" => refresh_token,
              "expires_in" => expires_in
            } = params

            token_expiration = DateTime.utc_now() |> DateTime.add(expires_in, :second)

            case Accounts.get_user_by_did(did, authorize?: false) |> dbg do
              {:ok, user} ->
                Accounts.update_user(
                  user,
                  %{
                    handle: Keyword.get(oauth_state, :handle),
                    access_token: access_token,
                    refresh_token: refresh_token,
                    token_expiration: token_expiration
                  },
                  actor: user
                )

                conn
                |> put_session(:current_user, user)
                |> assign(:current_user, user)
                |> dbg
                |> redirect(to: ~p"/dashboard")

              _ ->
                case Accounts.create_user(%{
                       did: did,
                       handle: Keyword.get(oauth_state, :handle),
                       access_token: access_token,
                       refresh_token: refresh_token,
                       token_expiration: token_expiration
                     }) do
                  {:ok, user} ->
                    conn
                    |> put_session(:current_user, user)
                    |> assign(:current_user, user)
                    |> redirect(to: ~p"/dashboard")

                  err ->
                    dbg(err)
                    conn |> put_status(500) |> json("error")
                end
            end
        end
    end

    # Verify state matches what you stored in session
    # Exchange code for tokens
    # Create/login user
  end

  defp create_client_assertion(audience) do
    client_id = client_id()

    jwt_payload = %{
      "iss" => client_id,
      "sub" => client_id,
      "aud" => audience,
      "jti" => :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false),
      "iat" => System.system_time(:second),
      "exp" => System.system_time(:second) + 300
    }

    jwt_header = %{
      "alg" => "ES256",
      "kid" => "key-1"
    }

    {_, private_jwk} = Application.fetch_env!(:skeet_deleter, :jwk_key)

    {_, signed_jwt_string} =
      private_jwk
      |> JOSE.JWT.sign(jwt_header, jwt_payload)
      |> JOSE.JWS.compact()

    signed_jwt_string
  end

  defp exchange_code_for_tokens(code, issuer, oauth_state) do
    client_id = client_id()
    redirect_uri = redirect_uri()

    # Create client assertion JWT
    client_assertion = create_client_assertion(issuer)

    code_verifier = Keyword.get(oauth_state, :code_verifier)
    token_endpoint = Keyword.get(oauth_state, :token_endpoint)
    dpop_nonce = Keyword.get(oauth_state, :dpop_nonce)
    dpop_proof = create_dpop_proof(token_endpoint, "POST", dpop_nonce)

    request_body =
      [
        grant_type: "authorization_code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        code: code,
        code_verifier: code_verifier,
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        client_assertion: client_assertion
      ]

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"DPoP", dpop_proof}
    ]

    case Req.post(token_endpoint, form: request_body, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 401, headers: headers}} ->
        # Check for new DPoP nonce in response
        new_nonce = get_dpop_nonce_from_headers(headers)
        oauth_state = Keyword.put(oauth_state, :dpop_nonce, new_nonce)

        if new_nonce && new_nonce != dpop_nonce do
          # Retry with new nonce
          exchange_code_for_tokens(code, issuer, oauth_state)
        else
          {:error, "Unauthorized"}
        end

      {:ok, response} ->
        {:error, response}
    end

    # case Req.post(token_endpoint, form: request_body, headers: [{}])

    # Make POST request to token endpoint (with DPoP header!)
    # You'll need to include DPoP proof here too
  end

  defp create_dpop_proof(url, method, nonce) do
    # Get your DPoP keypair (you need to store this from the PAR request)
    {dpop_private_key, dpop_public_key} = generate_dpop_keypair()

    # JWT header for DPoP
    dpop_header = %{
      "typ" => "dpop+jwt",
      "alg" => "ES256",
      "jwk" => dpop_public_key_as_jwk(dpop_public_key)
    }

    # JWT payload for DPoP
    dpop_payload = %{
      "jti" => :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false),
      # HTTP method
      "htm" => method,
      # HTTP URL
      "htu" => url,
      "iat" => System.system_time(:second),
      # The DPoP nonce from server
      "nonce" => nonce
    }

    # Sign the DPoP proof
    {_, dpop_jwt} =
      dpop_private_key
      |> JOSE.JWT.sign(dpop_header, dpop_payload)
      |> JOSE.JWS.compact()

    dpop_jwt
  end

  defp generate_dpop_keypair() do
    # Generate a new ES256 keypair for DPoP
    dpop_jwk = JOSE.JWK.generate_key({:ec, "P-256"})

    # Extract public key components for JWK format
    {_, public_map} = JOSE.JWK.to_public_map(dpop_jwk)

    {dpop_jwk, public_map}
  end

  defp dpop_public_key_as_jwk(dpop_public_key_map) do
    dpop_public_key_map
    |> Map.put("use", "sig")
    |> Map.put("alg", "ES256")
  end

  defp get_dpop_nonce_from_headers(headers) do
    Enum.find_value(headers, fn {name, value} ->
      if String.downcase(name) == "dpop-nonce", do: value
    end)
  end

  defp client_id, do: ~p"/bsky/oauth/client-metadata.json" |> url
  defp redirect_uri, do: ~p"/bsky/oauth/callback" |> url
end
