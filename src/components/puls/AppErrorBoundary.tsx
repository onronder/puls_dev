import { Component, type ErrorInfo, type ReactNode } from 'react'

import { captureAppError, type AppErrorContext } from '#/lib/observability/sentry'

import { AppErrorFallback } from './AppErrorFallback'

type AppErrorBoundaryProps = {
  children: ReactNode
  area?: AppErrorContext['area']
}

type AppErrorBoundaryState = {
  hasError: boolean
}

export class AppErrorBoundary extends Component<AppErrorBoundaryProps, AppErrorBoundaryState> {
  state: AppErrorBoundaryState = { hasError: false }

  static getDerivedStateFromError(): AppErrorBoundaryState {
    return { hasError: true }
  }

  componentDidCatch(error: Error, _errorInfo: ErrorInfo): void {
    captureAppError(error, {
      operation: 'react_error_boundary',
      area: this.props.area ?? 'unknown',
      route: typeof window === 'undefined' ? undefined : window.location.pathname,
    })
  }

  private reset = (): void => {
    this.setState({ hasError: false })
  }

  render() {
    if (this.state.hasError) {
      return <AppErrorFallback onReset={this.reset} />
    }

    return this.props.children
  }
}
