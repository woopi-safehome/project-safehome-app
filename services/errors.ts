export class NetworkError extends Error {
  constructor(
    message: string,
    public readonly url: string,
    cause?: unknown,
  ) {
    super(message, { cause });
    this.name = 'NetworkError';
  }
}

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly url: string,
    public readonly jobId?: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export class ParseError extends Error {
  constructor(
    message: string,
    public readonly jobId?: string,
  ) {
    super(message);
    this.name = 'ParseError';
  }
}
