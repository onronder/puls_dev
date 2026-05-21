import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_app/izin')({
  component: RouteComponent,
})

function RouteComponent() {
  return <div>Hello "/_app/izin"!</div>
}
