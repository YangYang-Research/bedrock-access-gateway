#!/usr/bin/env bash

set -o errexit  # exit on first error
set -o nounset  # exit on using unset variables
set -o pipefail # exit on any error in a pipeline

# Define variables
TAG="latest"
ARCHS=("arm64" "amd64")
PUBLIC_REGISTRY_ALIAS="j8d4r7c5"  # Replace with your actual public registry alias
REPO_NAME="third-party/bedrock-access-gateway"
REPOSITORY_URI="public.ecr.aws/${PUBLIC_REGISTRY_ALIAS}/${REPO_NAME}"
DOCKER_CONTEXT_PATH="../src"
AWS_REGION="us-east-1"  # ecr-public is only supported in us-east-1 for now

build_and_push_images() {
    local IMAGE_NAME=$1
    local TAG=$2
    local ENABLE_MULTI_ARCH=${3:-true}
    local DOCKERFILE_PATH=${4:-"${DOCKER_CONTEXT_PATH}/Dockerfile_ecs"}

    # Login to ECR Public
    echo "Logging in to Amazon ECR Public..."
    aws ecr-public get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin public.ecr.aws

    # Check if the ECR Public repository exists, create if it doesn't
    if ! aws ecr-public describe-repositories --region $AWS_REGION --repository-names "$REPO_NAME" > /dev/null 2>&1; then
        echo "Creating public ECR repository: $REPO_NAME"
        aws ecr-public create-repository --region $AWS_REGION --repository-name "$REPO_NAME"
    fi

    if [ "$ENABLE_MULTI_ARCH" == "true" ]; then
        # Build and push multi-arch image
        echo "Building multi-arch image: $IMAGE_NAME:$TAG"

        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            -t "$REPOSITORY_URI:$TAG" \
            -f "$DOCKERFILE_PATH" \
            --push \
            "$DOCKER_CONTEXT_PATH"

    else
        # Build and push single-arch image
        echo "Building single-arch image: $IMAGE_NAME:$TAG"
        docker buildx build \
            --platform linux/${ARCHS[0]} \
            -t "$REPOSITORY_URI:$TAG" \
            -f "$DOCKERFILE_PATH" \
            --push \
            "$DOCKER_CONTEXT_PATH"
    fi

    echo "Pushed $IMAGE_NAME:$TAG to $REPOSITORY_URI"
}

# Example invocations
build_and_push_images "bedrock-proxy-api" "$TAG" "false" "../src/Dockerfile"
build_and_push_images "bedrock-proxy-api-ecs" "$TAG"
