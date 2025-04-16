# # /********************************************************************************
# # * Copyright (c) 2022 Contributors to the Eclipse Foundation
# # *
# # * See the NOTICE file(s) distributed with this work for additional
# # * information regarding copyright ownership.
# # *
# # * This program and the accompanying materials are made available under the
# # * terms of the Apache License 2.0 which is available at
# # * http://www.apache.org/licenses/LICENSE-2.0
# # *
# # * SPDX-License-Identifier: Apache-2.0
# # ********************************************************************************/


# # ****************************************************************************
# # Building the Somip-Feeder Container
# # ****************************************************************************
# FROM --platform=$BUILDPLATFORM ubuntu:20.04 as builder

# ENV DEBIAN_FRONTEND="noninteractive"
# RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
#     apt-get install -y git \
#     cmake g++ build-essential g++-aarch64-linux-gnu \
#     binutils-aarch64-linux-gnu jq python3 python3-pip

# RUN pip3 install conan==1.55.0

# COPY . /src
# WORKDIR /src

# ARG TARGETPLATFORM
# RUN echo "Building for ${TARGETPLATFORM}"

# RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
#         ./build-release.sh amd64; \
#     elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
#         ./build-release.sh aarch64; \
#     else \
#         echo "Unsupported platform: $TARGETPLATFORM"; exit 1; \
#     fi
# # RUN ./build-release.sh $TARGETPLATFORM

# FROM --platform=$TARGETPLATFORM ubuntu:20.04 as final
# ARG TARGETARCH

# RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
#     apt-get install -y jq && \
#     rm -rf /var/lib/apt/lists/*

# WORKDIR "/app/lib"
# COPY --from=builder "/src/target/*/release/install/lib/*" "/app/lib"

# WORKDIR "/app/bin"
# COPY --from=builder "/src/target/*/release/install/bin" "/app/bin"

# RUN find /app 1>&2

# CMD [ "/app/bin/someip2val-docker.sh" ]

# ****************************************************************************
# Building the Somip-Client Container
# ****************************************************************************
# FROM --platform=$BUILDPLATFORM ubuntu:20.04 as builder

# ENV DEBIAN_FRONTEND="noninteractive"
# RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
#     apt-get install -y git \
#                        cmake \
#                        g++ \
#                        build-essential \
#                        g++-aarch64-linux-gnu \
#                        binutils-aarch64-linux-gnu \
#                        jq \
#                        python3 \
#                        python3-pip

# # Install a specific version of conan as required by the repository.
# RUN pip3 install conan==1.55.0

# # Copy the whole repository (both source and configuration)
# COPY . /src
# WORKDIR /src

# # Use TARGETPLATFORM to drive the build for the appropriate architecture.
# ARG TARGETPLATFORM
# RUN echo "Building for ${TARGETPLATFORM}"

# ENV VSOMEIP_APPLICATION_NAME=wiper_client

# # Call the build script with the appropriate argument:
# RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
#         ./build-release.sh amd64; \
#     elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
#         ./build-release.sh aarch64; \
#     else \
#         echo "Unsupported platform: $TARGETPLATFORM"; exit 1; \
#     fi

# FROM --platform=$TARGETPLATFORM ubuntu:20.04 as final
# ARG TARGETARCH

# RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
#     apt-get install -y jq && \
#     rm -rf /var/lib/apt/lists/*

# # Copy the runtime libraries – reusing what the builder generated.
# WORKDIR "/app/lib"
# COPY --from=builder "/src/target/*/release/install/lib/*" "/app/lib"

# # Copy the binaries – this should include the wiper_client binary.
# WORKDIR "/app/bin"
# COPY --from=builder "/src/target/*/release/install/bin" "/app/bin"

# # Create the configuration directory if not already present and copy the client config.
# RUN mkdir -p /app/bin/config
# COPY --from=builder "/src/config/someip_wiper_client.json" "/app/bin/config/someip_wiper_client.json"

# # (Optional) List the /app directory contents for debugging.
# RUN find /app 1>&2

# # Set required environment variables for the client application.
# ENV VSOMEIP_APPLICATION_NAME=wiper_client
# ENV VSOMEIP_CONFIGURATION=/app/bin/config/someip_wiper_client.json
# ENV LD_LIBRARY_PATH=/app/lib:$LD_LIBRARY_PATH

# # Set the command to run the wiper_client binary.
# CMD [ "/app/bin/wiper_client", "--mode", "2", "--freq", "50", "--pos", "110.0" ]

# ****************************************************************************
# Building the Somip-Service Container
# ****************************************************************************
FROM --platform=$BUILDPLATFORM ubuntu:20.04 as builder

ENV DEBIAN_FRONTEND="noninteractive"
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -y git \
                       cmake \
                       g++ \
                       build-essential \
                       g++-aarch64-linux-gnu \
                       binutils-aarch64-linux-gnu \
                       jq \
                       python3 \
                       python3-pip

# Install a specific version of conan as required by the repository.
RUN pip3 install conan==1.55.0

# Copy the whole repository (both source and configuration)
COPY . /src
WORKDIR /src

# Use TARGETPLATFORM to drive the build for the appropriate architecture.
ARG TARGETPLATFORM
RUN echo "Building for ${TARGETPLATFORM}"

ENV VSOMEIP_APPLICATION_NAME=wiper_service

# Call the build script with the appropriate argument:
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        ./build-release.sh amd64; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        ./build-release.sh aarch64; \
    else \
        echo "Unsupported platform: $TARGETPLATFORM"; exit 1; \
    fi

FROM --platform=$TARGETPLATFORM ubuntu:20.04 as final
ARG TARGETARCH

RUN DEBIAN_FRONTEND=noninteractive apt-get update -y && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

# Copy the runtime libraries – reusing what the builder generated.
WORKDIR "/app/lib"
COPY --from=builder "/src/target/*/release/install/lib/*" "/app/lib"

# Copy the binaries – this should include the wiper_service binary.
WORKDIR "/app/bin"
COPY --from=builder "/src/target/*/release/install/bin" "/app/bin"

# Create the configuration directory if not already present and copy the service config.
RUN mkdir -p /app/bin/config
COPY --from=builder "/src/config/someip_wiper_service.json" "/app/bin/config/someip_wiper_service.json"

# (Optional) List the /app directory contents for debugging.
RUN find /app 1>&2

# Set required environment variables for the service application.
ENV VSOMEIP_APPLICATION_NAME=wiper_service
ENV VSOMEIP_CONFIGURATION=/app/bin/config/someip_wiper_service.json
ENV LD_LIBRARY_PATH=/app/lib:$LD_LIBRARY_PATH

# Set the command to run the wiper_service binary.
CMD [ "/app/bin/wiper_service" ]