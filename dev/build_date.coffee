# Usage:
# node dev/build_date.js <in.html >out.html
#
# However, results in null output file if output equals input.

# Specify the build date pattern, which is a meta tag in an HTML header
date_regex = /(<meta name="build_date" content=").*?("><\/meta>)/g
# Replace with a current datestamp
date_now = "$1#{Date()}$2"

stdin = process.stdin
stdin.resume()
stdin.setEncoding 'utf8'
stdin.on 'data', (data) -> process.stdout.write data.replace date_regex, date_now
