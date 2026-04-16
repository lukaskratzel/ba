from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
MPLCONFIG_DIR = SCRIPT_DIR / ".mplconfig"
MPLCONFIG_DIR.mkdir(exist_ok=True)
os.environ.setdefault("MPLCONFIGDIR", str(MPLCONFIG_DIR))

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt

DEFAULT_DATA_DIR = SCRIPT_DIR / "data"
DEFAULT_OUTPUT_PATH = SCRIPT_DIR / "duration-boxplots.png"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create one chart with a boxplot per CSV using durationMs converted to seconds."
        )
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=DEFAULT_DATA_DIR,
        help="Directory containing benchmark CSV files.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_PATH,
        help="Path where the PNG plot should be written.",
    )
    return parser.parse_args()


def read_duration_seconds(csv_path: Path) -> list[float]:
    durations: list[float] = []

    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)

        if "durationMs" not in (reader.fieldnames or []):
            raise ValueError(f"{csv_path.name} is missing a durationMs column")

        for row_number, row in enumerate(reader, start=2):
            raw_duration = row.get("durationMs")
            if raw_duration is None or raw_duration == "":
                raise ValueError(
                    f"{csv_path.name}:{row_number} has an empty durationMs value"
                )

            try:
                durations.append(float(raw_duration) / 1000.0)
            except ValueError as error:
                raise ValueError(
                    f"{csv_path.name}:{row_number} has an invalid durationMs value: {raw_duration}"
                ) from error

    if not durations:
        raise ValueError(f"{csv_path.name} does not contain any benchmark rows")

    return durations


def create_plot(series_by_file: dict[str, list[float]], output_path: Path) -> None:
    labels = list(series_by_file.keys())
    series = [series_by_file[label] for label in labels]

    figure_width = max(8, len(labels) * 2.2)
    fig, ax = plt.subplots(figsize=(figure_width, 6))
    ax.boxplot(series, tick_labels=labels, patch_artist=True)
    ax.set_title("Benchmark Duration Distribution")
    ax.set_ylabel("Duration (seconds)")
    ax.set_xlabel("Input CSV")
    ax.grid(axis="y", linestyle="--", alpha=0.4)
    plt.setp(ax.get_xticklabels(), rotation=20, ha="right")
    fig.tight_layout()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=200)
    plt.close(fig)


def main() -> None:
    args = parse_args()
    data_dir = args.data_dir.resolve()
    output_path = args.output.resolve()

    csv_paths = sorted(data_dir.glob("*.csv"))
    if not csv_paths:
        raise SystemExit(f"No CSV files found in {data_dir}")

    series_by_file = {
        csv_path.stem: read_duration_seconds(csv_path) for csv_path in csv_paths
    }
    create_plot(series_by_file, output_path)
    print(f"Saved boxplot chart to {output_path}")


if __name__ == "__main__":
    main()
