vc ?= valk

test:
	$(vc) build ./tests --test --run
test-basic:
	$(vc) build ./tests --test --run --filter "Basics"
lint:
	$(vc) build ./src --lint
example:
	$(vc) build ./example --run
docs:
	$(vc) doc . -o docs/api.md --markdown --no-private
	$(vc) doc . -o docs/api-full.md --markdown --no-private --full
servers:
	./tests/servers.sh up
servers-down:
	./tests/servers.sh down

.PHONY: test test-basic lint example docs servers servers-down
