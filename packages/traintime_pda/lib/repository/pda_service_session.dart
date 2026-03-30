// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:dio/dio.dart';
import 'package:watermeter/repository/logger.dart';

Dio get dio => Dio()..interceptors.add(logDioAdapter);
