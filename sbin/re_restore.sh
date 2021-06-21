#!/bin/sh

nvram set restore_defaults=1 && nvram commit && reboot -f
