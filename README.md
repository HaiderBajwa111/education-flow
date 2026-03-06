# 🎓 Education Flow

**The North Star:** Operational Efficiency. A high-performance, multi-tenant School Management System designed for the Pakistani educational landscape, focusing on minimizing clicks for school staff.

---

## 🏗️ Architecture Stack
* **Frontend:** Next.js (TypeScript, Tailwind CSS, App Router)
* **Backend:** NestJS (TypeScript, Prisma ORM)
* **Database:** PostgreSQL (Dockerized)
* **Infrastructure:** Docker Compose (Postgres + Adminer)
* **Shared Logic:** Dedicated `@shared-types` for full-stack type safety

---

## 🛠️ Prerequisites
Before starting, ensure you have the following installed on your machine:
* [Node.js (v18 or higher)](https://nodejs.org/)
* [Docker Desktop](https://www.docker.com/products/docker-desktop/)
* [Git](https://git-scm.com/)

---

## 🚀 Getting Started

### 1. Clone & Install
Run these commands from your terminal:
```bash
# Clone the repository
git clone <your-repository-url>
cd education-flow

# Install root-level dependencies (concurrently, etc.)
npm install

# Install project-specific dependencies
cd backend && npm install
cd ../frontend && npm install
cd ..