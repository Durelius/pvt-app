
# Use the official Go image from Docker Hub
FROM golang:1.26-alpine

# Get FFMPEG to convert videos into GIFs


# Install Air for live-reloading
RUN apk add --no-cache gcc musl-dev git

RUN go install github.com/air-verse/air@latest

# Set the working directory in the container
WORKDIR /app

# Copy the Go modules and source code into the container
COPY go.mod go.sum ./
RUN go mod tidy

# Copy the rest of the application code into the container
COPY . .

EXPOSE 8081

# Command to run Air (start Go app with live-reloading)
CMD ["air"]
