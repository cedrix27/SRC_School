import type { Metadata } from 'next';
import '@fontsource/dm-sans/400.css';
import '@fontsource/dm-sans/500.css';
import '@fontsource/dm-sans/600.css';
import '@fontsource/dm-sans/700.css';
import './globals.css';
export const metadata: Metadata = { title: 'SRC SCHOOL · Votre école, simplement', description: 'Espace de gestion scolaire SRC SCHOOL' };
export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="fr"><body>{children}</body></html>; }
