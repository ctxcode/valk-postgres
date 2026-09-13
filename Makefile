vc ?= valk

test:
	$(vc) build ./tests --test --run
test-basic:
	$(vc) build ./tests --test --run --filter "Basics"
lint:
	$(vc) build ./src --lint
example:
	$(vc) build ./example --run
servers:
	./tests/servers.sh up
servers-down:
	./tests/servers.sh down

.PHONY: test test-basic lint example servers servers-down
