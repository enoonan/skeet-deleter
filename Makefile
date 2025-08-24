dev:
	docker stop local-postgres &> /dev/null || true; \
	docker rm local-postgres &> /dev/null || true; \
	docker run --name local-postgres -p 5432:5432 \
		-e POSTGRES_PASSWORD=postgres \
		-e POSTGRES_USER=postgres \
		-v $(PWD)/postgres:/var/lib/postgresql/data \
		-d --rm postgres:17; \
	iex --erl "+S 2:2" -S mix phx.server
