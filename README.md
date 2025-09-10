# LLM Prompt Firewall

A Ruby on Rails API application that serves as a security firewall for Large Language Model (LLM) prompts. It uses configurable regex patterns to detect and block potentially harmful, malicious, or unwanted prompts before they reach your LLM systems.

## Features

- **Regex-based Filtering**: Configurable YAML-based regex patterns for prompt validation
- **Multiple Actions**: Block, warn, or log suspicious prompts
- **Batch Processing**: Validate multiple prompts in a single API call
- **12-Factor App Compliant**: Environment-based configuration, stateless design
- **Comprehensive Logging**: Detailed logging with configurable levels
- **Health Monitoring**: Built-in health check endpoints
- **CORS Support**: Configurable cross-origin resource sharing
- **Hot Reload**: Runtime configuration reloading without restart

## Quick Start

### Prerequisites

- Ruby 3.3.6 or higher
- PostgreSQL 12 or higher
- Rails 8.0 or higher

### Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd llm-fw
```

2. Install dependencies:

```bash
bundle install
```

3. Set up environment variables:

```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Set up the database:

```bash
rails db:create
rails db:migrate
```

5. Start the server:

```bash
rails server
```

The API will be available at `http://localhost:3000`

## API Endpoints

### Health Check

```
GET /api/v1/prompts/health
```

Returns the service health status and configuration summary.

### Validate Single Prompt

```
POST /api/v1/prompts/validate
Content-Type: application/json

{
  "prompt": "Your prompt text here"
}
```

Response:

```json
{
  "allowed": true,
  "action": "allow",
  "message": null,
  "matched_patterns": [],
  "timestamp": "2025-01-09T19:35:00Z"
}
```

### Batch Validate Prompts

```
POST /api/v1/prompts/batch_validate
Content-Type: application/json

{
  "prompts": [
    "First prompt",
    "Second prompt",
    "Third prompt"
  ]
}
```

### Get Configuration

```
GET /api/v1/prompts/config
```

Returns current firewall configuration (patterns without regex details for security).

### Reload Configuration

```
POST /api/v1/prompts/reload_config
```

Reloads the configuration from the YAML file without restarting the service.

## Configuration

### Environment Variables

The application follows 12-factor app principles. All configuration is done via environment variables:

| Variable                          | Description                            | Default |
| --------------------------------- | -------------------------------------- | ------- |
| `PROMPT_FIREWALL_ENABLED`         | Enable/disable the firewall            | `true`  |
| `PROMPT_FIREWALL_DEFAULT_ACTION`  | Default action for matches             | `block` |
| `PROMPT_FIREWALL_LOGGING_ENABLED` | Enable logging                         | `true`  |
| `PROMPT_FIREWALL_LOG_LEVEL`       | Log level (debug, info, warn, error)   | `info`  |
| `PROMPT_FIREWALL_LOG_BLOCKED`     | Log blocked prompts                    | `true`  |
| `PROMPT_FIREWALL_LOG_ALLOWED`     | Log allowed prompts                    | `false` |
| `CORS_ORIGINS`                    | Allowed CORS origins (comma-separated) | `*`     |
| `DATABASE_URL`                    | PostgreSQL connection string           | -       |
| `PORT`                            | Server port                            | `3000`  |

### Pattern Configuration

Patterns are configured in `config/prompt_filters.yml`. The file supports environment-specific configurations:

```yaml
default: &default
  enabled: true
  default_action: block
  patterns:
    - name: "SQL Injection"
      pattern: '(?i)(union\s+select|drop\s+table)'
      action: block
      description: "Detects potential SQL injection attempts"
```

#### Pattern Actions

- **block**: Reject the prompt (HTTP 403)
- **warn**: Allow but flag for review (HTTP 200 with warning)
- **log**: Allow but log for monitoring (HTTP 200)

#### Built-in Pattern Categories

1. **Injection Attempts**: SQL injection, command injection
2. **Prompt Injection**: Instruction override attempts
3. **Information Extraction**: System prompt extraction attempts
4. **Harmful Content**: Violence, illegal activities
5. **Bypass Attempts**: Encoding, jailbreak patterns

## Security Features

### Pattern Matching

- Case-insensitive regex matching
- Multiple pattern support with severity levels
- Safe regex compilation with error handling

### Logging

- Structured JSON logging
- Configurable log levels
- No sensitive data in logs (prompt content limited)
- Timestamp and pattern matching details

### API Security

- Input validation and sanitization
- Rate limiting ready (add middleware)
- CORS configuration
- Error handling without information disclosure

## Deployment

### Docker

The application includes Docker support:

```bash
docker build -t llm-prompt-firewall .
docker run -p 3000:3000 --env-file .env llm-prompt-firewall
```

### Environment-specific Configuration

#### Development

```bash
RAILS_ENV=development
PROMPT_FIREWALL_DEFAULT_ACTION=warn
PROMPT_FIREWALL_LOG_LEVEL=debug
```

#### Production

```bash
RAILS_ENV=production
PROMPT_FIREWALL_ENABLED=true
PROMPT_FIREWALL_DEFAULT_ACTION=block
PROMPT_FIREWALL_LOG_LEVEL=info
DATABASE_URL=postgresql://user:pass@host:5432/llm_fw_production
```

## Monitoring

### Health Checks

- `/up` - Rails health check
- `/api/v1/prompts/health` - Application-specific health

### Logging

Structured logs include:

- Request/response details
- Pattern matches
- Performance metrics
- Error tracking

### Metrics

Ready for integration with:

- Prometheus/Grafana
- New Relic
- Sentry
- Custom monitoring solutions

## Development

### Running Tests

```bash
rails test
```

### Code Quality

```bash
bundle exec rubocop
bundle exec brakeman
```

### Adding New Patterns

1. Edit `config/prompt_filters.yml`
2. Add your pattern with appropriate action
3. Test with sample prompts
4. Reload configuration: `POST /api/v1/prompts/reload_config`

### Custom Actions

Extend the `PromptFirewallService` to add custom actions:

```ruby
def custom_action(prompt, matched_patterns)
  # Your custom logic here
end
```

## Architecture

### 12-Factor App Compliance

1. **Codebase**: Single codebase, multiple deploys
2. **Dependencies**: Explicit via Gemfile
3. **Config**: Environment variables
4. **Backing Services**: PostgreSQL as attached resource
5. **Build/Release/Run**: Separate stages
6. **Processes**: Stateless, share-nothing
7. **Port Binding**: Self-contained web service
8. **Concurrency**: Process model via Puma
9. **Disposability**: Fast startup/shutdown
10. **Dev/Prod Parity**: Consistent environments
11. **Logs**: Treat as event streams
12. **Admin Processes**: One-off tasks via Rails console

### Components

- **PromptFirewallService**: Core filtering logic
- **PromptsController**: API endpoints
- **Configuration**: YAML-based with environment overrides
- **Logging**: Structured logging with multiple levels

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure code quality checks pass
5. Submit a pull request

## License

[Add your license here]

## Support

For issues and questions:

- Create an issue in the repository
- Check the logs for detailed error information
- Use the health check endpoints for diagnostics
