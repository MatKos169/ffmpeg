# FFmpeg TS to MP4 Conversion Service (Forked)

This repository is a fork of [liofal/ffmpeg](https://github.com/liofal/ffmpeg) with custom modifications to automate the conversion of `.ts` video files to `.mp4` format, including audio normalization and a date-organized output folder structure to optimize usage with Jellyfin Media Server.

---

## Prerequisites

- Docker  
- Docker Compose

---

## Getting Started

### Clone the Repository

```sh
git clone https://github.com/<your-username>/ffmpeg.git
cd ffmpeg
```

---

## Configuration

Create a `.env` file in the project root directory with the following content:

```env
SLEEPTIME=600
WORKDIR=/app/downloads
OUTPUTFOLDER=your_streamer_name
```

**Descriptions:**

- `SLEEPTIME`: Time in seconds to wait before the next conversion cycle.  
- `WORKDIR`: Directory where the `.ts` files are located.  
- `OUTPUTFOLDER`: Name for output folder grouping converted files (must be overridden; default is `streamername`).

---

## Build and Run the Docker Container

Use Docker Compose to build and run the container:

```sh
docker-compose up --build
```

The service will automatically:

- Convert `.ts` files in the `WORKDIR` into `.mp4` files with audio normalization.
- Place them into `/app/output/{OUTPUTFOLDER}-{year}/{month}/`.
- Move original `.ts` files to a `processed` subfolder to avoid re-processing.

---

## Volumes

Update the `volumes` section in `docker-compose.yml` to mount your local directories:

```yaml
volumes:
  - /path/to/local/downloads:/app/downloads
  - /path/to/local/output:/app/output
```

---

## Stopping the Service

To stop the service, run:

```sh
docker-compose down
```

---

## Notes

- The script **warns** if `OUTPUTFOLDER` is not overridden from its default `streamername`.
- Audio normalization uses FFmpeg's `loudnorm` filter.
- The container is based on **Ubuntu 24.04**.
- Filename collisions for `.mp4` output are handled by appending numbers.

---

## Original Repository

This project is a fork and modification of the original:

👉 [liofal/ffmpeg](https://github.com/liofal/ffmpeg)

Thanks to **liofal** for providing the base project.

---

## License

This project is licensed under the **MIT License**.
