# Use Google's official Dart image to build
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and AOT compile it.
COPY . .
# Ensure dependencies are up to date
RUN dart pub get --offline
RUN dart compile exe bin/main.dart -o bin/rea

# Build minimal serving image
# We use a small linux base that includes git (alpine typically needs git installed)
FROM alpine:latest

# Install git/git-lfs as REA relies on the 'git' command on PATH
RUN apk add --no-cache git openssh

# Copy the binary from the build stage
COPY --from=build /app/bin/rea /usr/local/bin/rea

# Set the working directory to a volume mount point
WORKDIR /repo

# Entry point allows passing arguments directly to the binary
ENTRYPOINT ["rea"]
