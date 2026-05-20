import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { Session, User } from '@supabase/supabase-js'

import { supabase, type PersonaRole } from '#/lib/supabase'

export type ActivePersona = 'employee' | 'manager'

type AuthContextValue = {
  session: Session | null
  user: User | null
  personaRole: PersonaRole | null
  activePersona: ActivePersona
  hasDualPersona: boolean
  isLoading: boolean
  signIn: (email: string, password: string) => Promise<{ error: string | null }>
  signOut: () => Promise<void>
  setActivePersona: (persona: ActivePersona) => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [personaRole, setPersonaRole] = useState<PersonaRole | null>(null)
  const [activePersona, setActivePersonaState] = useState<ActivePersona>('employee')
  const [isLoading, setIsLoading] = useState(true)

  const loadPersona = useCallback(async (userId: string) => {
    const { data } = await supabase
      .from('employees')
      .select('persona_role, tenant_id')
      .eq('user_id', userId)
      .maybeSingle()

    const role = (data?.persona_role as PersonaRole | undefined) ?? 'employee'
    setPersonaRole(role)

    if (role === 'manager' || role === 'hr_admin') {
      setActivePersonaState('manager')
    } else {
      setActivePersonaState('employee')
    }
  }, [])

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      if (data.session?.user) {
        void loadPersona(data.session.user.id)
      }
      setIsLoading(false)
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
      if (nextSession?.user) {
        void loadPersona(nextSession.user.id)
      } else {
        setPersonaRole(null)
        setActivePersonaState('employee')
      }
    })

    return () => subscription.unsubscribe()
  }, [loadPersona])

  const hasDualPersona = personaRole === 'manager' || personaRole === 'hr_admin'

  const signIn = useCallback(async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    return { error: error?.message ?? null }
  }, [])

  const signOut = useCallback(async () => {
    await supabase.auth.signOut()
  }, [])

  const setActivePersona = useCallback(
    async (persona: ActivePersona) => {
      setActivePersonaState(persona)

      if (session?.user) {
        await supabase.schema('audit').from('audit_logs').insert({
          tenant_id: null,
          actor_id: session.user.id,
          action: 'persona_switch',
          target_object: { persona },
          request_metadata: { source: 'PersonaTogglePill' },
        })
      }
    },
    [session],
  )

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      personaRole,
      activePersona,
      hasDualPersona,
      isLoading,
      signIn,
      signOut,
      setActivePersona,
    }),
    [
      session,
      personaRole,
      activePersona,
      hasDualPersona,
      isLoading,
      signIn,
      signOut,
      setActivePersona,
    ],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
