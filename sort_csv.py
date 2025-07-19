#!/usr/bin/env python3
import csv
import sys

def count_x_chars(row):
    """Count the number of 'x' characters in the Opcode Mask column"""
    return row[1].count('x')

def main():
    # Read the CSV file
    with open('opcodes.csv', 'r') as file:
        reader = csv.reader(file)
        header = next(reader)  # Read the header
        rows = list(reader)    # Read all data rows

    # Sort rows by the number of 'x' characters in the Opcode Mask column
    sorted_rows = sorted(rows, key=count_x_chars)

    # Write the sorted CSV back to the file
    with open('opcodes.csv', 'w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(header)  # Write header first
        writer.writerows(sorted_rows)  # Write sorted rows

    print("CSV file has been sorted by increasing number of 'x' characters in each row.")

    # Print some statistics
    print(f"Total rows: {len(sorted_rows)}")
    print(f"Range of 'x' counts: {count_x_chars(sorted_rows[0])} to {count_x_chars(sorted_rows[-1])}")

if __name__ == "__main__":
    main()
