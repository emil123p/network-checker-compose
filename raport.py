from datetime import datetime, timedelta, timezone
from pathlib import Path
from statistics import mean, median
import sys

LOG_FILE = Path("logs/wyniki.log")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("1h", "24h"):
        print("Użycie: python3 raport.py 1h | 24h")
        return

    period = timedelta(hours=1) if sys.argv[1] == "1h" else timedelta(hours=24)
    now = datetime.now(timezone.utc)
    cutoff = now - period

    if not LOG_FILE.exists():
        print(f"Nie znaleziono pliku: {LOG_FILE}")
        return

    records = []
    response_times = []

    with LOG_FILE.open("r", encoding="utf-8") as file:
        for line in file:
            try:
                timestamp = datetime.fromisoformat(line.split()[0])
            except (ValueError, IndexError):
                continue

            if not cutoff <= timestamp <= now:
                continue

            if "status=OK" in line:
                status = "OK"
                for part in line.split():
                    if part.startswith("response_ms="):
                        try:
                            response_times.append(float(part.split("=", 1)[1]))
                        except ValueError:
                            pass
                        break
            elif "status=FAIL" in line:
                status = "FAIL"
            else:
                continue

            records.append((timestamp, status))
    records.sort(key=lambda record: record[0])

    # Wykrywanie przerw w monitoringu
    max_gap = timedelta(seconds=45)
    gaps = []

    for i in range(1, len(records)):
        previous_time = records[i - 1][0]
        current_time = records[i][0]
        gap = current_time - previous_time

        if gap > max_gap:
            gaps.append((previous_time, current_time, gap))

    print(f"\nPrzerwy w monitoringu (> {max_gap.total_seconds():.0f} s): {len(gaps)}")

    for number, (start, end, duration) in enumerate(gaps, start=1):
        print(
            f"Przerwa {number}: "
            f"ostatni pomiar {start.isoformat()}, "
            f"następny pomiar {end.isoformat()}, "
            f"czas przerwy {duration}"
        )

    total_gap_time = sum(
        (duration for _, _, duration in gaps),
        timedelta()
    )
    print(f"Łączny czas przerw: {total_gap_time}")

    if records:
        last_timestamp, last_status = records[-1]
        print(f"Ostatni pomiar: {last_timestamp.isoformat()}")
        print(f"Status ostatniego pomiaru: {last_status}")
    else:
        print("Brak danych o ostatnim pomiarze.")

    total = len(records)

    successful = sum(status == "OK" for _, status in records)
    failed = total - successful

    print(f"=== RAPORT: ostatnie {sys.argv[1]} ===")
    print(f"Wszystkie próby: {total}")
    print(f"Udane połączenia: {successful}")
    print(f"Nieudane połączenia: {failed}")

    if total:
        print(f"Dostępność z zarejestrowanych prób: {successful / total * 100:.2f}%")
        if gaps:
            print("UWAGA: wykryto przerwy w monitoringu; wynik nie opisuje całego okresu.")    
    else:
        print("Brak prób w wybranym okresie.")

    if response_times:
    	print(f"Minimalny czas odpowiedzi: {min(response_times):.2f} ms")
    	print(f"Mediana czasu odpowiedzi: {median(response_times):.2f} ms")
    	print(f"Średni czas odpowiedzi: {mean(response_times):.2f} ms")
    	print(f"Maksymalny czas odpowiedzi: {max(response_times):.2f} ms")


    failures = []
    current_failures = []

    for timestamp, status in records:
        if status == "FAIL":
            current_failures.append(timestamp)
        elif current_failures:
            failures.append((current_failures, timestamp))
            current_failures = []

    if current_failures:
        failures.append((current_failures, None))


    print(f"\nSerie awarii: {len(failures)}")

    for number, (series, recovery) in enumerate(failures, start=1):
        start = series[0]
        last_failure = series[-1]

        if recovery is not None:
            duration = recovery - start
            recovery_info = f"przywrócenie: {recovery.isoformat()}"
            duration_info = f"szacowany czas do przywrócenia: {duration}"
        else:
            recovery_info = "brak późniejszego udanego pomiaru"
            duration_info = "czas trwania nieustalony"

        print(
            f"Seria {number}: {len(series)} błędów, "
            f"od {start.isoformat()} do {last_failure.isoformat()}, "
            f"{recovery_info}, {duration_info}"
        )

    if failures:
        longest = max(failures, key=lambda item: len(item[0]))
        print(f"Najwięcej błędów w jednej serii: {len(longest[0])}")

if __name__ == "__main__":
    main()
