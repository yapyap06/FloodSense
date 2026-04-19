# Use Nginx to serve the static content
FROM nginx:alpine

# Copy the build output to the nginx html directory
COPY build/web /usr/share/nginx/html

# Expose port 8080 (Cloud Run expects 8080 by default, or we can use 80)
EXPOSE 8080

# Update nginx configuration to listen on 8080 and handle SPA routing
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf

# Add a configuration for SPA routing (try files)
RUN sed -i '/index  index.html index.htm;/a \        try_files $uri $uri/ /index.html;' /etc/nginx/conf.d/default.conf

CMD ["nginx", "-g", "daemon off;"]
