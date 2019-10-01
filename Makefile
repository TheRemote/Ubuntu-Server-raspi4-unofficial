.PHONY: all
all: docker/boot up

.PHONY: up
up:
	docker-compose up --build

.PHONY: down
down:
	docker-compose down

.PHONY: destroy
destroy:
	docker-compose down --volumes
