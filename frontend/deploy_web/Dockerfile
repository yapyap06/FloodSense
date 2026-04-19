# Use Nginx to serve the static content
FROM nginx:alpine

# Copy the build output to the nginx html directory
# Since we are deploying from the 'deploy_web' folder, everything is in the root
COPY . /usr/share/nginx/html

# Expose port 8080
EXPOSE 8080

# Update nginx configuration
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf
RUN sed -i '/index  index.html index.htm;/a \        try_files $uri $uri/ /index.html;' /etc/nginx/conf.d/default.conf

CMD ["nginx", "-g", "daemon off;"]
