version: '3.3'

services:
  postgres:
    image: postgres:13
    container_name: fisioapp-postgres
    restart: always
    ports:
      - "5432:5432"  # Expose postgres port for external access
    environment:
      POSTGRES_USER: ${db_user}
      POSTGRES_PASSWORD: ${db_password}
      POSTGRES_DB: ${db_name}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    command: ["postgres", "-c", "log_statement=all", "-c", "listen_addresses=*"]
    networks:
      - app-network

  backend:
    image: ${docker_image_repo}:${backend_image_tag}
    container_name: fisioapp-backend
    restart: always
    ports:
      - "3000:3000"
    depends_on:
      - postgres
    env_file:
      - backend.env
    networks:
      - app-network

  frontend:
    image: ${docker_image_repo}:${frontend_image_tag}
    container_name: fisioapp-frontend
    restart: always
    ports:
      - "80:80"
    depends_on:
      - backend
    environment:
      - VITE_API_URL=${api_url}
    networks:
      - app-network

volumes:
  postgres_data:
    external: true

networks:
  app-network:
    driver: bridge