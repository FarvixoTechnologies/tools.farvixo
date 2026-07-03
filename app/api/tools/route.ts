import { apiOk } from '@/lib/api-response';
import { tools } from '@/data/tools';
import { categories } from '@/data/categories';

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const category = searchParams.get('category')?.trim() || '';
  const sort = searchParams.get('sort') || 'popular';

  let list = category ? tools.filter((t) => t.category === category) : [...tools];

  if (sort === 'name') list.sort((a, b) => a.name.localeCompare(b.name));
  else if (sort === 'new') list = list.filter((t) => t.badge === 'new').concat(list.filter((t) => t.badge !== 'new'));
  else list = list.sort((a, b) => (b.badge === 'popular' ? 1 : 0) - (a.badge === 'popular' ? 1 : 0));

  return apiOk({
    total: list.length,
    categories: categories.map((c) => ({ slug: c.slug, name: c.name, count: tools.filter((t) => t.category === c.slug).length })),
    tools: list.map((t) => ({
      id: t.id,
      slug: t.slug,
      name: t.name,
      description: t.description,
      category: t.category,
      badge: t.badge ?? null,
      href: `/tools/${t.category}/${t.slug}`,
    })),
  });
}
