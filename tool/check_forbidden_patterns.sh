#!/usr/bin/env bash
# Fails when the code breaks an architecture rule of this project.
#
#   - No reactive GetX state, GetX workers, Bindings, or other HTTP clients.
#   - Only the data layer and the composition root use the networking package
#     and the database.
#   - Controllers never call update() without ids.
#   - Every GetBuilder in a feature has an id.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0
fail() {
  echo "FAIL: $1"
  status=1
}

forbidden='\.obs\b|Rx<|Rxn|RxList|RxMap|RxSet|Obx\(|GetX<|BindingsBuilder|\bBindings\b|binding:|initialBinding|\bever\(|\bonce\(|\bdebounce\(|\binterval\(|package:dio|package:http/|GetConnect|chopper|retrofit'
if grep -rnE "$forbidden" lib test integration_test tool --include='*.dart'; then
  fail 'forbidden pattern found (see lines above)'
fi

outside=$(grep -rlE 'flutter_network_plus|package:drift' lib | grep -vE '^lib/(data|di)/' || true)
if [ -n "$outside" ]; then
  echo "$outside"
  fail 'networking or database package used outside lib/data and lib/di'
fi

if grep -rnE 'NetworkClient|AppDatabase|LocalDataSource|RemoteDataSource' lib/features lib/domain lib/core; then
  fail 'data access type referenced from features, domain or core'
fi

if grep -rn 'update()' lib; then
  fail 'update() without ids; pass the ids of the widgets to rebuild'
fi

missing=$(awk '
  /GetBuilder</ { line = FNR; file = FILENAME; found = 0; window = 3 }
  window > 0 { if ($0 ~ /id:/) found = 1; window--;
               if (window == 0 && !found) print file ":" line }
' $(find lib/features -name '*.dart'))
if [ -n "$missing" ]; then
  echo "$missing"
  fail 'GetBuilder without an id'
fi

if [ "$status" -eq 0 ]; then
  echo 'Architecture checks passed.'
fi
exit "$status"
