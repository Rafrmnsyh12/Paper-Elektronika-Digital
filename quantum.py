import os
import numpy as np
import matplotlib.pyplot as plt

from qiskit import QuantumCircuit, transpile
from qiskit_aer import AerSimulator
from qiskit.visualization import plot_histogram, circuit_drawer


def ensure_outdir(outdir: str) -> str:
    os.makedirs(outdir, exist_ok=True)
    return outdir


# Fungsi simulasi state transition FSM menggunakan Quantum Gates + export gambar
def simulate_fsm_quantum(sensors, shots=1024, tag="case", outdir="outputs", show=False):
    """
    sensors: list/tuple panjang 6, berisi 0/1
      - 0 = abnormal
      - 1 = normal
    Output state diukur pada (Q2,Q1,Q0) -> bitstring c2c1c0

    Produces:
      - circuit_<tag>.png
      - hist_<tag>.png
    """
    if len(sensors) != 6 or any(v not in (0, 1) for v in sensors):
        raise ValueError("sensors harus list panjang 6, tiap elemen 0 atau 1.")

    outdir = ensure_outdir(outdir)

    # 6 qubit sensor (0..5), 3 qubit state (6..8), 3 classical bits (0..2)
    qc = QuantumCircuit(9, 3)

    # Inisialisasi sensor: jika abnormal (0), kita X supaya jadi 1 (agar bisa jadi kontrol)
    for i, val in enumerate(sensors):
        if val == 0:
            qc.x(i)

    # Emergency condition: kalau semua sensor abnormal (setelah X -> semua kontrol = 1),
    # maka set Q2=1 (state 100) menggunakan multi-controlled X (MCX)
    qc.mcx([0, 1, 2, 3, 4, 5], 6)  # target qubit state Q2

    # Ukur state qubits: (Q2,Q1,Q0) -> (c2,c1,c0)
    qc.measure([6, 7, 8], [2, 1, 0])

    # ====== 1) SIMPAN GAMBAR RANGKAIAN ======
    circuit_path = os.path.join(outdir, f"circuit_{tag}.png")
    # output="mpl" butuh matplotlib + kadang pylatexenc di Windows
    fig_circ = circuit_drawer(qc, output="mpl")
    fig_circ.savefig(circuit_path, dpi=300, bbox_inches="tight")
    plt.close(fig_circ)

    # ====== 2) RUN SIMULASI ======
    backend = AerSimulator()
    tqc = transpile(qc, backend)
    result = backend.run(tqc, shots=shots).result()
    counts = result.get_counts(tqc)

    print(f"\n=== {tag.upper()} ===")
    print(f"Input Sensor: {sensors}")
    print(f"Hasil Measurement State (c2c1c0): {counts}")

    # ====== 3) SIMPAN HISTOGRAM ======
    hist_path = os.path.join(outdir, f"hist_{tag}.png")
    fig_hist = plot_histogram(counts)
    fig_hist.savefig(hist_path, dpi=300, bbox_inches="tight")
    if show:
        plt.show()
    plt.close(fig_hist)

    return counts, circuit_path, hist_path


def save_summary_hist(counts_dict, outdir="outputs", filename="summary_hist.png"):
    """
    counts_dict: dict dengan key=label, value=counts
    Membuat 1 gambar histogram gabungan (lebih bagus untuk laporan).
    """
    outdir = ensure_outdir(outdir)
    path = os.path.join(outdir, filename)

    # Buat figure
    fig = plt.figure()
    # plot_histogram bisa menerima dict of dict: {"label": counts, ...}
    fig = plot_histogram(counts_dict)
    fig.savefig(path, dpi=300, bbox_inches="tight")
    plt.close(fig)

    return path


if __name__ == "__main__":
    # Output folder
    OUTDIR = "outputs"
    SHOTS = 1024

    # Test Case 1: Emergency Condition (All Sensors 0) -> harap dominan '100'
    counts_emg, circ_emg, hist_emg = simulate_fsm_quantum(
        [0, 0, 0, 0, 0, 0],
        shots=SHOTS,
        tag="emergency",
        outdir=OUTDIR,
        show=False
    )

    # Test Case 2: Normal Condition (All Sensors 1) -> harap dominan '000'
    counts_norm, circ_norm, hist_norm = simulate_fsm_quantum(
        [1, 1, 1, 1, 1, 1],
        shots=SHOTS,
        tag="normal",
        outdir=OUTDIR,
        show=False
    )

    # Histogram gabungan (1 gambar)
    summary_path = save_summary_hist(
        {"Emergency": counts_emg, "Normal": counts_norm},
        outdir=OUTDIR,
        filename="summary_hist.png"
    )

    print("\n=== FILE OUTPUT ===")
    print("Circuit Emergency :", circ_emg)
    print("Hist Emergency    :", hist_emg)
    print("Circuit Normal    :", circ_norm)
    print("Hist Normal       :", hist_norm)
    print("Summary Histogram :", summary_path)
    print("\nSelesai. Cek folder:", OUTDIR)
