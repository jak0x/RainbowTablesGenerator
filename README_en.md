# RainbowGen CLI

Classic Rainbow Table generator with support for multiple algorithms, parallel execution with CPU load control, automatic upload to AWS S3, optional compression, and flexible configuration via JSON.

---

## Key Features

- Classic rainbow table generation (`rtgen`, `rtsort`)
- Multi-algorithm support in a single config file (`--multi`)
- Parallel processing with system load control (`loadavg` + `nproc`)
- Automatic upload of `.rt` or `.rt.gz` files to Amazon S3
- Optional compression with `gzip` (`--compress`)
- Installable via `.deb` or Docker
- `--upload-only` mode for uploading pre-generated tables

---

## Installation

### Option 1: Docker

```bash
docker build -t rainbowgen .
```

```bash
docker run --rm -v $PWD:/app rainbowgen --config config.json --multi
```

### Option 2: `.deb` package

```bash
./rainbowgen_installer.sh
sudo dpkg -i rainbowgen_1.0_amd64.deb
```

```bash
rainbowgen --config config.json --multi
```

---

## ⚙️ Basic Usage

```bash
rainbowgen \
  --config config.json \
  --multi \
  --threads 4 \
  --compress
```

### Available Flags

| Flag            | Description |
|-----------------|-------------|
| `--config`      | JSON file with global configuration and job list |
| `--multi`       | Processes all algorithms defined in the JSON file |
| `--upload-only` | Only uploads `.rt` or `.rt.gz` files to S3, no generation |
| `--threads`     | Number of threads to use for parallel jobs |
| `--compress`    | Compresses `.rt` files before uploading to S3 |
| `--help`        | Displays the help menu |

---

## Example `config.json`

```json
{
  "global": {
    "threads": 4,
    "bucket": "my-rainbow-bucket",
    "compress": true
  },
  "jobs": [
    {
      "algo": "md5",
      "charset": "mixalpha-numeric",
      "min": 1,
      "max": 6,
      "chainlen": 2100,
      "chainnum": 33554432,
      "table": 0,
      "start": 0,
      "parts": 2
    },
    {
      "algo": "sha1",
      "charset": "loweralpha",
      "min": 1,
      "max": 5,
      "chainlen": 1000,
      "chainnum": 1000000,
      "table": 1,
      "start": 0,
      "parts": 1
    }
  ]
}
```

---

## Repository Structure

```
.
├── Dockerfile                 # Docker image definition
├── rainbow_gen_parallel_s3.sh # Main Bash script with all logic
├── rainbowgen_installer.sh    # .deb packaging script
├── config.json                # Sample configuration file
├── README.md                  # This documentation 😄
```

---

## Requirements

- Ubuntu/Debian environment
- `awscli`, `jq`, `gzip`, `bc`, `make`
- AWS account and credentials configured

---

## Contact

Created by jak0x. For suggestions, contributions or questions, open an issue or pull request.

---

## License

MIT License. Use it for educational, legal, and ethical purposes only.
