# BuildKit starts a nested container for the RUN step, and runc must mount a fresh
# /proc inside a user namespace.
FROM alpine:3.22
RUN mkdir -p /www \
	&& echo ok > /www/health \
	&& echo "built by a RUN step on $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /www/index.html
EXPOSE 8080
CMD ["httpd", "-f", "-p", "8080", "-h", "/www"]
