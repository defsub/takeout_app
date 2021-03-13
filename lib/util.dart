
bool isNullOrEmpty(String s) => s?.trim()?.isEmpty ?? true;

bool isNotNullOrEmpty(String s) => s?.trim()?.isNotEmpty ?? false;

const kilobyte = 1024;
const megabyte = kilobyte*1024;
const gigabyte = megabyte*1024;

String storage(int size) {
  int n = size ~/ gigabyte;
  if (n > 0) {
    return '$n GB';
  }
  n = size ~/ megabyte;
  if (n > 0) {
    return '$n MB';
  }
  n = size ~/ kilobyte;
  if (n > 0) {
    return '$n KB';
  }
  return '$size B';
}
