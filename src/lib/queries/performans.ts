import { supabase } from '#/lib/supabase'

export type CompetencyTemplate = {
  id: string
  name: string
  description: string | null
  weight: number | null
  sort_order: number | null
}

export async function fetchCompetencyTemplates(): Promise<CompetencyTemplate[]> {
  const { data, error } = await supabase
    .from('performans_competency_templates')
    .select('id, name, description, weight, sort_order')
    .eq('is_active', true)
    .order('sort_order', { ascending: true })

  if (error) {
    console.warn('fetchCompetencyTemplates:', error.message)
    return []
  }

  return (data ?? []) as CompetencyTemplate[]
}
