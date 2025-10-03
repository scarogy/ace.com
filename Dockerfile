# Use Bitnami WordPress as base (matches what's deployed)
FROM public.ecr.aws/bitnami/wordpress:6.6.2-debian-12-r9

# Switch to root to install packages
USER root

# Add any customizations you need
RUN apt-get update && apt-get install -y \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Copy custom themes/plugins if you have them
# COPY ./my-theme /opt/bitnami/wordpress/wp-content/themes/my-theme
# COPY ./my-plugin /opt/bitnami/wordpress/wp-content/plugins/my-plugin

# Custom PHP configuration (optional)
# RUN echo "upload_max_filesize = 64M" > /opt/bitnami/php/etc/conf.d/uploads.ini
# RUN echo "post_max_size = 64M" >> /opt/bitnami/php/etc/conf.d/uploads.ini

# Switch back to non-root user (Bitnami security best practice)
USER 1001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Use Bitnami's entrypoint (important!)
CMD ["/opt/bitnami/scripts/wordpress/run.sh"]