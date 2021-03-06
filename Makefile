CONTAINER=gcr.io/grpc-demo-1

gen/todos.pb.go: todos.proto
	docker run --rm -v `pwd`:/defs namely/protoc-all:1.28_1 -f todos.proto -l go -o gen
	docker run -v `pwd`/todos.proto:/defs/todos.proto -v `pwd`/gen:/defs/gen namely/protoc:1.28_1 -I . --descriptor_set_out=gen/todos.pb --include_source_info --include_imports todos.proto
	#docker run -v `pwd`/todos.proto:/defs/todos.proto -v `pwd`/gen:/defs/gen namely/gen-grpc-gateway -f todos.proto -s Todos

.PHONY: protogen
protogen: gen/todos.pb.go

.PHONY: build
build: todos.proto
	docker build --target server -t ${CONTAINER}/todos-server .
	docker build --target client -t ${CONTAINER}/todos-client .
	#docker build -t ${CONTAINER}/todos-gateway gen/grpc-gateway

# .PHONY: deploy-gateway
# deploy-gateway: deploy-gateway
# 	docker push ${CONTAINER}/todos-gateway
# 	kubectl apply -f k8s/todos-gateway.yaml

.PHONY: deploy-server
deploy-server: protogen
	docker push ${CONTAINER}/todos-server
	kubectl apply -f k8s/todos-server.yaml

.PHONY: deploy-client
deploy-client: protogen
	docker push ${CONTAINER}/todos-client
	kubectl apply -f k8s/todos-client.yaml

# .PHONY: deploy-endpoints
# deploy-endpoints:
# 	docker run -v `pwd`/todos.proto:/defs/todos.proto -v `pwd`/gen:/defs/gen namely/protoc:1.28_1 -I . --descriptor_set_out=gen/api_descriptor.pb --include_source_info --include_imports todos.proto
# 	gcloud endpoints services deploy gen/api_descriptor.pb gcp-endpoints/api_config.yaml

.PHONY: envoy
envoy:
	docker run -it --rm --name envoy -p 9901:9901 -p 51051:51051 \
		-v `pwd`/gen/todos.pb:/data/todos.pb:ro \
		-v `pwd`/envoy-config.yml:/etc/envoy/envoy.yaml:ro \
		envoyproxy/envoy
