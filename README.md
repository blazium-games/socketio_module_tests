# Blazium Engine SocketIO Client Module Tests

This repository contains [GUT (Godot Unit Test)](https://github.com/bitwes/Gut)-based tests
that comprehensively validate the functionality of the integrated C++ SocketIO client within
the [Blazium Engine](https://github.com/blazium-games/blazium).

## Running the Tests
To execute the tests in a headless environment, use the following command structure against your local Blazium Editor executable:

```bash
blazium --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
