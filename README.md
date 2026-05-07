A powerful, free, and open-source way to clean and speed up a macOS system directly from the terminal is by using Mole. It is a command-line tool that automatically removes application leftovers, clears caches, and reclaims disk space, making it a popular free alternative to paid optimization tools
by saving the following into a .sh file 


# Run IN CMD making it executable (chmod +x mac_cleaner.sh)

chmod +x mac_cleaner.sh

# Run interactive menu
sudo ./mac_cleaner.sh

# Run everything silently (no menu)
sudo ./mac_cleaner.sh --all

# Safe preview mode (nothing deleted)
sudo ./mac_cleaner.sh --dry-run
