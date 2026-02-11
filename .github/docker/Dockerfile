FROM kivy/buildozer:latest

# Create a non-root user 'builder' and set up permissions
RUN useradd -m builder || true
RUN chown -R builder:builder /home/user || true

USER builder
WORKDIR /home/user/host
